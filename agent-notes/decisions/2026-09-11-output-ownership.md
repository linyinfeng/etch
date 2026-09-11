# 输出目录的所有权（`.lpignore`）（2026-09-11）

起因：用户问「删除一个文件 chunk 时会发生什么」。实测（main 上的 `5ec7aa7`）：

```
tangle 两个根 → out/a.py out/b.py
删掉 <b.py> chunk 再 tangle → 只打印 "ok a.py"，out/b.py 原地不动（内容还是旧的）
lp tangle --check          → exit 0（漂移检查通过）
lp map --file b.py         → "not in the line map"
```

也就是：**删掉/改名一个根 chunk 会留下一个孤儿文件**，而残留的 `src/*.rs` 照样会被 cargo 编译。这在"生成物不入库"的模型里是最危险的一类漏网——`--check` 本该守住的漂移，反而看不见。

---

## D10 — 两层所有权：账本 + 目录声明

- **决定**：
  1. **`.lpmap.json` 当账本（ledger），不当快照。** 一条记录会**在其 chunk 被删除后继续保留**（对应的文件还在磁盘上时）；文件消失则记录被清掉。含义：`lp` 知道自己写过哪些文件，即使现在的文档不再产出它们。
  2. **`.lpignore` = 目录级所有权声明。** 某个目录里有 `.lpignore`，就表示"这个目录里的文件是 `lp` 的，除了文件里列出的那些"。该目录下（递归，嵌套的 `.lpignore` 同样生效）任何**没有 chunk 产出且未被忽略**的文件会被删除。忽略规则用 `ignore` crate（ripgrep 同源）解析，语法等同 `.gitignore`（glob、`!取反`、`dir/`）。
  3. **点文件永不删除**（`.lpmap.json`、`.lpignore`、`.gitignore`…），无论规则怎么写。
  4. **没有 `.lpignore` 时保守行事**：只考虑账本里记过、且当前文档不再产出的文件，且**必须显式 `--prune`** 才删除；默认只报告 `orphan`。
  5. **`--check` 永不删除**，它是干跑：把本该删掉的列成 `ORPHAN`（含 "would be removed"），并以非零退出。`--check` 与 `--prune` 互斥（clap 层面）。
  6. 删除文件后，**它所属的空目录链会被收起**（只收自己刚清空的那些，不扫全树）。
- **落选**：
  - 只做账本孤儿（本次会话最初实现）：漏掉"从来不是我们写的"残留（换 `--out` 跑过一次、旧版本留下的文件），而且第一个 pass 写回新 map 后孤儿记录就没了——测试 `map_orphans_are_reported_and_need_prune_without_an_ignore_file` 当场抓住了这个 bug（`--prune` 无效）。账本语义修掉了它。
  - 只做 `.lpignore` 扫描：没有 ignore 的目录完全没有保护/提示。
  - 一律要求 `--prune` 才删：`.lpignore` 已经是显式选择加入（用户的设计原话是"就会被删除"），再叠一层开关是冗余摩擦。
  - 复用 `.gitignore` 语义直接读 `.gitignore`：会把"git 忽略但确是 `lp` 产物"的情形搞混；显式文件名更清楚。
- **风险与缓解**（诚实记录）：`--out .` 配一份写得太松的 `.lpignore` 会删掉项目文件。缓解：①所有权必须逐目录显式声明（没有任何 `.lpignore` 就什么都不扫）；②点文件豁免；③`lp tangle --check` 是干跑，先看再删；④被忽略的文件永不动。
- **影响**：
  - `.lpmap.json` 的语义变化要在 README 里写明（账本而非快照）。
  - `lp tangle`/`lp watch` 都会执行扫描（watch 里删文件后同样触发 `--check-cmd`）。
  - `--prune` 保留，服务于没有 `.lpignore` 的场景。
- **回归**：`tests/owned.rs` 6 个用例（删除根 chunk → 文件与空目录一起消失；忽略文件全部存活；没有 `.lpignore` 时不动 map 之外的东西；`--check` 干跑；点文件豁免；无 ignore 时孤儿需 `--prune`）。另加 `lp map` 的账本行为由 `tests/flow.rs`/`tests/lazy.rs` 覆盖。
