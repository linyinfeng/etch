# 实时 / lazy tangle（分支 `lazy-tangle`）

- 日期：2026-09-11
- 动机（用户提出）：除了批量 tangle，能否**实时**地把代码"同构 fuse lazy"地 tangle 出来。
- 结论：**值得做，但真正的价值不在"算得快"，而在"写得少"**。实测：2201 行 / 200 个根 chunk 的文档，全量重算只要 7ms（release），所以增量解析、反向可达这些"真 lazy"手段在当前规模**没有必要**；而每次改一个 fragment 会重写几个文件、触发 cargo/rust-analyzer 重建——这才是要解决的问题。已实现：只覆写真正变化的文件 + 合并编辑事件 + 语法错误不 tangle + 把 check 回路接上（诊断自动回译到 `.typ`）。
- 待决定：是否把这个分支合回 main（见文末）。

## 1. 把想法拆成三个可验证的命题

| 命题 | 含义 | 实测/实现 |
| --- | --- | --- |
| 实时 | 编辑时自动同步，不需要手动跑命令 | `lp watch`（notify + debouncer，默认 200ms 合并窗口） |
| lazy | 不做无谓的工作：不重算没变的、不重写没变的、不在你半句话时动手 | 只覆写字节变化的文件；无变化时连 `.lmap.json` 都不写；SyntaxError 时跳过整轮 |
| 同构 / fuse | 文档 ↔ 生成代码的投影是活的、双向的，并且"检查"这一环也接进同一个回路 | `lp map --typ` 反向投影；`--check-cmd` 触发后把 rustc 诊断回译成 `.typ` 行 |

"fuse" 我按"融进同一条回路"理解：**编辑 `.typ` → 同步 → 跑检查 → 诊断指回 `.typ`**，全程没有手工步骤。真正开放的极端形态是 FUSE 文件系统 / LSP 虚拟文档（见 §5）。

## 2. 实测数据

合成文档：2201 行、200 个根 chunk（生成脚本见 §6）。

| 场景 | debug | release |
| --- | --- | --- |
| 首次全量（解析 + 展开 200 个根 + 写盘） | 18 ms | 7 ms |
| 无变化的一轮 | 11 ms | 3 ms |
| 改 1 个 fragment 后的一轮 | — | 重写 **1** 个文件，**200** 个原样不动 |

demo 文档（3 个根）在 watch 里的内部计时：

```
sync   3 rewritten, 0 untouched (1.3ms): Cargo.toml, src/lib.rs, src/main.rs   ← 初始
sync   1 rewritten, 2 untouched (1.4ms): src/main.rs                            ← 改一个 fragment
   Compiling lp-demo ...
src/main.rs:6:38: error[E0425]: cannot find function `ad` in module `math`
  ↳ examples/demo/literate.typ:92 (chunk <<print-results>>)
    ╭─[examples/demo/literate.typ:92:1]
 92 │ println!("add(2, 3) = {}", math::ad(2, 3));
    ·                      ╰── generated from examples/demo/literate.typ:92
```

（编辑到 `.typ`，1.4ms 后同步完成，cargo 只重建了 `lp-demo`，错误直接指到 `.typ:92` 并带源码片段。）

**结论**：`typst-syntax::reparser`（增量解析）和 chunk 反向可达（只展开受影响的根）在本规模下都是纯浪费——全量重算 3–7ms。先用"写入去重"把无谓的 IO 消掉，把这两条留到真的出现书级文档（数量级 ~10^5 行）时再上，`src/watch.rs` 顶部已用 `ponytail:` 注记了这个天花板。

## 3. 实现要点（`src/watch.rs` + 两处小重构）

1. **只写变化的字节**：`tangle::run` 不再自己打印，而是返回 `Outcome { changed, unchanged, stale, warnings }`；比较的是"展开结果 vs 磁盘内容"。未变化的文件 **mtime 不动**，所以 cargo / rust-analyzer 不会被无谓唤醒。这条有测试守着（`tests/lazy.rs::a_pass_does_not_touch_files_that_did_not_change`，断言三个文件的 mtime 完全相等）。
2. **无变化时连 `.lpmap.json` 都不重写**（否则 map 本身就是个"每次都变"的抖动源）。
   ⚠️ **2026-09-11 修正**：这句话一开始被理解成"输出没变就不写 map"，那是错的——map 的内容取决于**文档**（插入一行散文就平移所有映射），输出字节完全不变。正确做法是比较 map 自身的内容（`LpMap::write_if_changed`），并用测试锁住“只加散文也要更新映射”（`tests/flow.rs::the_map_follows_the_document_even_when_no_output_byte_changes`）。当时 `lp map` 报了 93 行而实际在 95 行，而且指向一个空行——正是这个 bad case。
3. **合并编辑事件**：`notify-debouncer-full` 做时间窗口合并；一轮开始前把已排队事件抽干（`try_recv`），避免自己的写盘反过来触发下一轮。监听的是**文档所在目录**（NonRecursive）而不是文件本身——编辑器保存是"写临时文件 + rename"，盯文件的 watch 会掉。
4. **半写状态的文档不 tangle**：`SyntaxNode::errors_and_warnings()` 是权威的解析诊断来源（只找 `SyntaxKind::Error` 节点会漏掉未闭合字符串这类错误，我在测试里踩到了）。有语法错误就打印诊断、跳过本轮，**保留上一份好产物**——这在实时回路里比"尽量凑合"重要得多。
5. **check 回路融合**：`--check-cmd 'cargo build --message-format=short'` 只在一轮真的改写了文件后执行（无变化的事件不会去跑 cargo），输出走与 `lp explain` 完全相同的回译路径。
6. **反向投影**：`lp map --typ <doc> --line N` 列出该 `.typ` 行产生（可能不唯一）的生成位置，"同构"就不再是单向的。

## 4. 顺手暴露的一个真问题

实时回路要求"毫秒级、可反复跑"，这把 `lp` 的**行为契约**逼清楚了：写不写、写什么、什么时候拒绝，都必须有测试。新增 `tests/lazy.rs` 5 个用例（mtime 不变 / 只重写受影响文件 / 半写文档不 tangle / 双向 map / 未引用 chunk 告警），加上原有 14 个，共 19 个测试全绿。

## 5. 没做，以及为什么（诚实的天花板）

- **FUSE / 虚拟文件系统**（生成的代码只存在于内存，读时才物化；甚至可以让写入失败，强迫 agent 回到 `.typ`）：技术上可行（`fuser` 等 crate，Linux only），对"agent 手改生成物"这个失败模式有根治效果（写操作直接报错）。但现在收益不明显：写入去重已经消掉了主要抖动，而 FUSE 带来挂载生命周期、性能、编辑器兼容的一整套运维面。**留作后续**，前提是有人真的被"agent 改生成物"坑过。
- **LSP 虚拟文档 / 投影**（把 tangling 结果作为 .typ 的子文档暴露给编辑器，位置双向映射）：Ravel 有 `ravel-projection` / `ravel-language-service` 做这个，是最完整的形态；我们目前的 `.lpmap.json` + `lp map` 已经是它的数据底座。
- **增量解析 / 反向可达**：见 §2 结论。

## 6. 复现命令

```sh
# 实时回路（demo）
cd ~/Projects/worktrees/literate/lazy-tangle
nix develop -c cargo run -- watch examples/demo/literate.typ --out examples/demo/build \
    --check-cmd "cargo build --manifest-path examples/demo/build/Cargo.toml --message-format=short"
# 然后在另一个终端编辑 examples/demo/literate.typ

# 规模基准
python3 - <<'PY'
import pathlib
lines = ["= Synthetic big document\n"]
for i in range(200):
    lines += [f"== Section {i}\n", f"```py\n<<frag{i}>>\n``` <mod{i}.py>\n",
              f"```py\ndef f{i}(x):\n    return x + {i}\n``` <frag{i}>\n"]
pathlib.Path("/tmp/big.typ").write_text("\n".join(lines))
PY
cargo build --release && time ./target/release/lp tangle /tmp/big.typ --out /tmp/big-out
```

## 7. 待决定

- 合回 main？（`lp watch` + 反向 map + 语法错误门 + 三个小重构都是增量、不破坏既有行为；19 个测试全绿）
- 若合并：`watch` 的"只写变化文件 + 语法错误不 tangle"应写成 ADR（行为契约），并把 `--check-cmd` 的默认值（如自动探测 `Cargo.toml` / `pyproject.toml`）留给下一轮讨论。
- 是否把 FUSE / LSP 投影列为 M2 的可选项（我建议：先不做，等真实踩坑）。
