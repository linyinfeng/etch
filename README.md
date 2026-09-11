# literate

基于 [Typst](https://typst.app) 的 literate programming 工具：**同一个 `.typ` 文件既是可排版的文档，也是目标语言源码的唯一真相**，并且与目标语言正交——tangle 只做 chunk 组合与缩进，不解析目标语言。

```sh
nix develop                     # typst 0.15 + cargo 1.97
lp tangle doc.typ --out out     # 把文档展开成源码
typst compile --root . doc.typ  # 把文档排成 PDF
```

## 文档长什么样

普通的 Typst 文档；**带 label 的 fenced code block 就是 chunk**：

````
```python
<<imports>>
print(greet("world"))
``` <main.py>                       # label 像文件名 → 这是一个输出文件

```python
from greet import greet
``` <imports>                        # 普通 chunk，被 <<imports>> 引用

```python
def greet(name):
    return f"hello, {name}"
``` #label("src/greet.py")            # 需要目录时用 Typst 的 constructor 写法
````

- `<<name>>` 独占一行时是引用，展开时按引用点的缩进整体缩进；其他位置（`std::cout << x`）保持字面量。
- 同名 label 的多块按文档顺序拼接（noweb / org-babel `:noweb-ref` 语义）。
- 根 chunk（label 看起来像文件名的）按 `--out` 写成文件；其余 chunk 只出现在被引用的地方。
- Typst 的 `<...>` label 只允许 `[A-Za-z0-9_.:-]`，**不含 `/`**，所以带目录的名字要用 `#label("src/main.rs")`。两种写法都原生、都可以被 `query` 看到（`@name` / show rule 同样适用）。

## 命令

```
lp tangle <doc.typ>... [--out DIR] [--check]
                                               # 展开；--check 不写文件、发现漂移则退出码 1
lp watch  <doc.typ>... [--out DIR] [--debounce MS] [--check-cmd CMD]
                                               # 编辑时自动同步，只重写真正变了的文件；
                                               # 有变化时跑 CMD 并把诊断回译到 .typ
lp map    --file src/main.rs --line 42         # 生成文件的第 42 行来自哪一行 .typ
lp map    --typ doc.typ --line 92              # 反向：这一行 .typ 产生了哪些生成位置
lp explain [--out DIR]                         # 把 file:line:col 诊断翻译回 .typ（读 stdin）
lp list   <doc.typ>                            # 列出 chunk：根/片段、语言、源行号、是否被引用
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
  ↳ examples/demo/literate.typ:92 (chunk <<print-results>>)
    ╭─[examples/demo/literate.typ:92:1]
 92 │ println!("add(2, 3) = {}", math::add(2, 3));
    ·                       ╰── generated from examples/demo/literate.typ:92
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

## 行号映射

**每个目录一份**：`out/.lpmap.json` 只管 `out/` 里直接躺着的文件，`out/src/.lpmap.json` 只管 `out/src/` 里的。渐进式披露——你打开哪个目录就读哪份映射，不用面对一棵树的全局索引；映射跟着它解释的文件走，目录消失时它也一起消失（删掉一个 `src/foo.rs` 的根 chunk，那份映射里就没有它了）。

```json
// examples/demo/build/.lpmap.json
{ "version": 3, "docs": ["examples/demo/literate.typ"],
  "files": { "Cargo.toml": { "sources": ["examples/demo/literate.typ"], "lang": "toml",
                             "lines": [[1, 25, 0], [7, 31, 0]],
                             "chunks": [{ "name": "Cargo.toml", "typ_line": 25, "end_line": 33 }] } } }
```

`lines` 是 `[该目录内的生成文件行, 源文件行, sources 下标]`，指向**定义处**而不是引用处。`sources` 通常只有一个元素；当一本书拆成多章、某个输出文件的正文来自两个文件时才不止一个，诊断因此总能指到**真正含那一行的文件**。查询时按"最具体的目录优先"解析：`lp map --file src/main.rs` 用 `src/` 的映射；只给文件名（`--file main.rs`）而多个目录都有同名文件时，报歧义而不是猜。生成物不入库：CI 跑 `lp tangle --check`，漂移即失败。

## 多章文档

```sh
lp tangle book.typ chapter-one.typ chapter-two.typ --out out
```

根 chunk 只要出现在**任意一个**文档里即可（"没有 root"是整次调用的判定，不是每个文件）；`<<ref>>` 可以跨文件引用（按命令行给出的文件顺序拼接同名 chunk）。每个输出文件的映射会记下它真正用到的源文件，`lp map` / `lp explain` 因此指到正确的文件与行。

还没做：**跟随 `#include`**（Typst 的 include 是内容级合并，chunk 与 heading 都会并入文档；我们目前只解析命令行里列出的文件），以及 Typst 侧的结构元数据（见 `agent-notes/research/2026-09-11-typst-structure-and-include.md`）。

## 状态

原型可用（M1 + `lp explain` 的通用后端）；详见 [`agent-notes/`](agent-notes/README.md)：

- [`agent-notes/plan.md`](agent-notes/plan.md) — M0–M3 计划与已完成范围
- [`agent-notes/decisions/`](agent-notes/decisions/) — 已拍板的 ADR（架构、引擎、依赖、chunk 命名）
- [`agent-notes/research/`](agent-notes/research/) — 现有工具盘点、Typst 实测事实、设计空间
- [`experiments/`](experiments/) — 两个丢弃型验证（Python 端到端 spike、`typst-syntax` span probe）

下一步：`lp watch`（notify）、`lp explain --format cargo`（cargo JSON）、列位置精确到诊断坐标、以及自举（工具自身源码改写成 literate `.typ`）。
