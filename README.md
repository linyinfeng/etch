# literate

基于 [Typst](https://typst.app) 的 literate programming 工具：**同一个 `.typ` 文件既是可排版的文档，也是目标语言源码的唯一真相**，并且与目标语言正交——tangle 只做 chunk 组合与缩进，不解析目标语言。

```sh
nix develop                     # typst 0.15 + cargo 1.97
lp tangle doc.typ --out out     # 把文档展开成源码
typst compile --root . doc.typ  # 把文档排成 PDF
```

## 文档长什么样

普通的 Typst 文档，加一个包：**chunk 由声明给出**。

````
#import "lit/lp.typ": chunk, file, rule
#show: rule

= The program

#chunk("imports", ```python
from greet import greet
```)

#file("src/main.py", ```python
<<imports>>
print(greet("world"))
```)

#file("src/greet.py", ```python
def greet(name):
    return f"hello, {name}"
```)
````

- `#file(path, …)` 声明**输出文件**，`#chunk(name, …)` 声明**片段**——名字、语言、正文都在声明里，工具不需要读源码猜。
- `<<name>>` 独占一行时是引用，展开时按引用点的缩进整体缩进；其他位置（`std::cout << x`）保持字面量。**要原样展示这一行**就用转义 `@<<name>>`——它照样输出 `<<name>>`，但不会被展开（ADR D17；skill 与本文档自己就靠它）。
- **名字必须先被引用、后被声明**（ADR D16）：读者总是先遇到名字，再遇到填进它的正文；把细节写在名字之前，`lp` 拒绝。片段展开进文件时语言（fence 的 tag）也必须与该文件一致。
- **同名的多个声明按文档顺序拼接**（noweb / org-babel `:noweb-ref` 语义）——一个文件可以分几处写。
- 包负责渲染（带标题的块 + 引用标记），文档不需要任何样式化 show rule；`#show: rule` 只是让 `<<引用>>` 显示成绿色。
- 没有"名字看起来像文件名"之类的启发式：是不是输出文件由 `file` 还是 `chunk` 决定。

## 命令

```
lp tangle <doc.typ>... [--out DIR] [--check]
                                               # 展开；--check 不写文件、发现漂移则退出码 1
lp watch  <doc.typ>... [--out DIR] [--debounce MS] [--check-cmd CMD]
                                               # 编辑时自动同步，只重写真正变了的文件；
                                               # 有变化时跑 CMD 并把诊断回译到 .typ
lp map    --file src/main.rs --line 42         # 生成文件的第 42 行来自哪个 chunk、在它里面第几行
lp map    --typ print-results                  # 反向：这个 chunk 产生了哪些生成行
lp explain [--out DIR]                         # 把 file:line:col 诊断翻译回 .typ（读 stdin）
lp list   <doc.typ>                            # 列出 chunk：file/片段、语言、是否被引用
lp metadata <doc>...                           # 让 Typst 求值并打印它的有序事件流（调试用）
lp unaccounted <doc>... [--out DIR] [--delete]  # 列出（或显式删除）既没有 chunk 产出、也没被声明的文件
```

退出码：0 成功，1 语义错误（悬空引用 / 引用环 / 空 chunk / 漂移），2 用法错误。

## 实时（`lp watch`）

```sh
lp watch examples/demo/literate.typ --out examples/demo/build \
  --check-cmd "cargo build --manifest-path examples/demo/build/Cargo.toml --message-format=short"
```

语义（都有测试，见 `tests/lazy.rs`）：

- **只写变化**：一轮同步比较展开结果与磁盘内容，未变的文件连 mtime 都不变，cargo / rust-analyzer 不会被无谓重建。
- **半写文档不 tangle**：有语法错误就打印诊断并跳过本轮，保留上一份好产物（编辑器里的一一瞬态不会把代码弄坏）。
- **事件合并**：`notify` 的 debouncer（默认 200 ms）加“抽干自己的写盘事件”，一次编辑一轮。
- **check 融合**：`--check-cmd` 只在真的改写了文件后才跑，输出走与 `lp explain` 相同的回译路径。

代价与天花板：每轮全量解析 + 全量展开，实测 2201 行 / 200 个根的文档全量 7 ms、无变化 3 ms（release），所以没有做增量解析或反向可达；规模再大两个数量级再说。详见 [`agent-notes/research/2026-09-11-lazy-tangle.md`](agent-notes/research/2026-09-11-lazy-tangle.md)。

## 流程（可运行）

`nix develop -c examples/demo/run.sh` 会跑完整条链路：tangle 一个多文件 Rust crate → `cargo run` 并与文档里写死的输出比对 → weave 出 PDF → `--check` 无漂移 → `lp map` 定位一行 → 故意写错一行让 rustc 报错、再用 `lp explain` 把错误翻译回 `.typ` → 复原。

关键输出（诊断回译）：

```
src/main.rs:6:38: error[E0425]: cannot find function `ad` in module `math`
  ↳ chunk ⟪print-results⟫, line 1 of it  (src/main.rs:6)
    find it with: rg '#chunk("print-results")'
```

## 删除与目录所有权

删掉（或改名）一个根 chunk 后，它产出的文件会留在磁盘上。**删不删由目录声明决定**：在声明目录里会被自动清掉，没声明就一个字都不动（`--check` 会把声明目录里"会被删"的列出来，一个文件也不删）。

要让一个目录完全归 `lp` 管，在里面放一份 `.lpignore`：**规则就是 gitignore 的**（glob、`!`、`**`、`dir/`、嵌套文件与"深层覆盖浅层"的优先级都由 `ignore` crate 处理，一次遍历搞定）。该目录下任何**没有 chunk 产出且未被规则匹配**的文件会被删除；匹配上的文件留下。demo 里 `examples/demo/build/.lpignore` 就是例子（cargo 的 `target/`、`Cargo.lock`、weave 出来的 PDF 都列在里面）。

两点要说清：**匹配语法和优先级与 gitignore 相同，但"匹配上了"的含义相反**——gitignore 里匹配=不跟踪，这里匹配=**保护**（把它当"要保留什么"的清单来读就对了）。豁免的只有两个控制文件 `.lpmap.json` 与 `.lpignore`，其余包括点文件都是普通内容——没有 `git` 特例，要留 `.git` 就写一条 `.git/`。

干跑用 `lp tangle --check`：它列出会被删的东西，一个文件也不动。没有任何 `.lpignore` 时 `lp` 不删任何东西——它不保留"我以前写过什么"的记录，授权只来自目录声明。

输出目录里的每个文件恰好落在三类之一，而且只有第三类是需要有人告诉你的：

| | 在哪能看见 | 谁负责 |
|---|---|---|
| **produced**：某个 chunk 产出它 | 所在目录的 `.lpmap.json` | `lp`——`--check` 守它的漂移 |
| **declared**：`.lpignore` 里写了 | ignore 文件本身 | 你——`lp` 不碰它 |
| **unaccounted**：都不是 | **哪里都看不见** | 没人 |

`--out` 指向哪个目录，**整个目录就是 `lp` 的**：下面每个文件都必须被解释。解释不了就是**错误**——`lp tangle` 会失败（`--check` 同样）并逐条列出，给你两条出路：

```sh
lp unaccounted doc.typ --out out            # 看清有哪些（退出码 1）
lp unaccounted doc.typ --out out --delete   # 显式删掉它们（这就是那个 force）
# 或者在所在目录的 .lpignore 里声明它们
```

**`lp` 从不自行删除任何东西**：没有自动扫描删除这回事，删除只发生在你显式要求时。报告基于**当前文档**（重新展开来判断什么算产出），所以"刚删掉一个 chunk"的残留文件一定会被列出来。展示上逐文件列名（可 grep、可粘进 `.lpignore`）；只有子树的未处置文件超过 8 个才压缩成一行目录名。

清单上如果有"程序真正需要、只是没被解释"的东西（`flake.lock`、锁文件、清单），正确做法不是继续声明"我不管理"，而是写进文档——作为一个**附录 chunk**，让散文解释它为什么长这样。

## 出处（chunk 级，不是行号）

每个输出文件旁边一份 `.lpmap.json`（每目录一份），记的是 **chunk 区间**：哪一段输出行来自哪个声明、在声明里从第几行开始。

```json
// examples/demo/build/.lpmap.json
{ "version": 5, "docs": ["examples/demo/literate.typ"],
  "files": { "Cargo.toml": { "lang": "toml",
                             "runs": [{ "chunk": "Cargo.toml", "first": 1, "last": 7 }] } } }
```

```sh
$ lp map --file src/main.rs --line 6
chunk ⟪print-results⟫, line 1 of it
$ echo 'src/main.rs:6:38: error: …' | lp explain
  ↳ chunk ⟪print-results⟫, line 1 of it  (src/main.rs:6)
```

**没有 `.typ:行号`，这是有意的**：Typst 脚本层拿不到源位置（元素没有 span，`location` 只是排版坐标），要行号就得在源码里搜索声明 token、或把 Typst parser 放回工具里——两种都不优雅，按项目的准入规矩就不做（见 `agent-notes/decisions/2026-09-11-no-positions.md`）。chunk 名是更好的指针：`rg '#chunk("print-results"'` 一步就到声明。

## 自举（仓库自己就是产物）

`self.typ` 描述这个 crate 自己：`Cargo.toml`、`src/*.rs`、`tests/*.rs` 都是它的声明，**都不入库**。仓库里 tracked 的是 `bootstrap/`——冻结的种子，不随文档更新（工具坏掉时它是唯一可信起点）。

clone 之后先跑种子，再跑工具：

```sh
nix develop -c cargo build --manifest-path bootstrap/Cargo.toml
nix develop -c ./bootstrap/target/debug/lp tangle self.typ --out .
nix develop -c cargo test
```

之后改工具就是改 `self.typ`（实时回路：`lp watch self.typ --out . --check-cmd 'cargo build --message-format=short'`）。手改 `src/` 会被 `tests/self.rs` 抓住——它跑 `lp tangle self.typ --out . --check`，要求文档复现**正在运行的那份源码**。

`--out` 是仓库根，所以根 `.lpignore` 列出所有手写资产（`lit/`、`agent-notes/`、`bootstrap/`、`examples/`……）；新增顶层文件要顺手声明它，否则 `tangle` 报"未处置"。选型与落选方案见 [`agent-notes/decisions/2026-09-11-self-hosting-layout.md`](agent-notes/decisions/2026-09-11-self-hosting-layout.md)。

## 状态

原型可用：M1 + M2（`lp watch`、输出目录所有权、chunk 级出处）+ **自举 Stage 1**（`self.typ` 逐字节复现整个 crate，`bootstrap/` 是种子）。详见 [`agent-notes/`](agent-notes/README.md)：

- [`agent-notes/handoff.md`](agent-notes/handoff.md) — **接手先读这份**：行为契约、铁规矩、已知脏点、下一步候选
- [`agent-notes/plan.md`](agent-notes/plan.md) — M0–M3 计划与已完成范围
- [`agent-notes/decisions/`](agent-notes/decisions/) — 已拍板的 ADR（架构、chunk 声明、输出所有权、watch 契约、无行号、自举布局）
- [`agent-notes/research/`](agent-notes/research/) — 现有工具盘点、Typst 实测事实、设计空间
- [`experiments/`](experiments/) — 丢弃型验证（Python 端到端 spike、`typst-syntax` span probe、Stage 1 的转写脚本）
- [`.agents/skills/literate-programming/`](.agents/skills/literate-programming/SKILL.md) — agent skill：怎么写 LP、lp 下的机制、以及结构强制不了的那半边（语义自洽）。**它自己也由 `self.typ` 生成**（ADR D17 的转义就是为它加的）

未做：`lp explain --format cargo`（cargo JSON）、`ci.sh`、自举 Stage 2（抽公共 chunk、加散文、按章节拆）——候选与代价见 handoff §6。
