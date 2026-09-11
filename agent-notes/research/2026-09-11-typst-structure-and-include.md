# Typst 文档自身的结构，以及 include（实测，2026-09-11）

- 环境：typst 0.15.1（nixpkgs）。
- 动机：用户问"Typst 文档本身是结构化的吗？可以 include 吗？"——这决定了大型 literate 程序能否按章节拆分，以及"结构"能不能替代一部分我们自造的东西（label 命名、chunk 归属）。

## 1. 结构：有，而且是一等元素

`heading` 是可查询元素，字段齐全：

```sh
$ typst eval 'query(heading).map(h => h.level)' --in struct.typ
[1,2,3,1,1]

$ typst eval 'query(heading).map(h => h.fields().keys())' --in struct.typ
[["level","depth","offset","numbering","supplement","outlined","bookmarked","hanging-indent","body"], ...]
```

即：`level`（层级）、`depth`、`numbering`、`supplement`、`outlined`（是否进目录）、`bookmarked`、`body`（内容）。`#outline()` 就是基于它的。**层级是隐含的**——没有 section 对象，结构由 heading 的先后与 level 序列推导（Typst 代码在 `#context` 里能算出这棵树，我们的 Rust 侧遍历语法树同样能）。

对我们的意义：`headings` + `query` 足以让我们知道"一个 chunk 属于哪一节"，或者在 woven 文档里做分节导航（`#outline()` 白拿）。

## 2. include：是内容级合并

```sh
$ typst eval 'query(raw.where(block: true)).map(e => str(e.at("label", default: none)))' --in main.typ
["from-inc.py"]        # main.typ 里只有 #include "inc/chapter.typ"
$ typst eval 'query(heading).map(h => h.level)' --in main.typ
[1,1]                  # 被 include 文件的 heading 并入本文档的结构
```

- `#include "x.typ"` **把内容插进文档**：里面的 chunk、heading、label 全部成为本文档的一部分（label 是文档级全局的）。
- `#import "x.typ": name` 只带**定义**，不带内容、也不带 show rule（show rule 那条之前验证过）。
- 因此：Typst 层面的"多文件一本书"是 include 出来的，而不是 import 出来的。

（顺带两个 Typst 自身的语义，与 include 无关：`@ref` 不能指向 raw block，要放进 figure；heading 要有 `numbering` 才能被 `@` 引用。）

## 3. `lp` 今天的表现（两个缺口）

```sh
$ lp list main.typ                  # main.typ 只有 #include
main.typ: 0 chunks
outputs: (none)

$ lp tangle main.typ --out out
× main.typ: no root chunks
```

1. **不跟随 include**：`typst-syntax` 只解析单个文件，我们把 `#include` 当成一个 Code 节点就过去了。所以被 include 的 chunk 对 `lp` 是不可见的——在"未处置即错误"的规则下这会很坑：章节里的 root chunk 产出的文件会变成"没人解释"。
2. **跨文档引用不成立**：`lp tangle main.typ chapter.typ` 也不行，因为 `ChunkSet` 是**按文档**建的（`chunk <<greeting>> is not defined`）。所以"书拆成多章"这条路的两个层次都不通。

### 本轮已修的一个小 bug

`no root chunks` 原来是**逐文档**判定的，于是"某一章全是散文、root 在另一章"会被拒绝——而多章文档里这是常态。改成**整次调用**判定（任一文档有 root 即可；全都没有才报错），并且把语法错误门放在它前面（否则半写状态会先报 "no root chunks"，掩盖真正的错误）。

## 4. 要真正支持"一本书拆成多章"，还差什么

| 缺口 | 代价 | 说明 |
| --- | --- | --- |
| 跨文档 ChunkSet | 小 | 把 `ChunkSet` 建在全部文档的 blocks 上；`Block` 需要携带"我属于哪个文件"（`Arc<FileText>`），展开时的报错 span 用它取 |
| 跟随 `#include` | 中 | 遍历语法树找 `#include("literal.typ")`，递归解析并把 blocks 按 include 位置拼接（深度优先即文档顺序），带环路检测；不需要求值 Typst，只认字面量路径 |
| 映射的 per-line 源文件 | 中（schema v3） | 一旦一个输出文件的行来自**两个**文件（同名 label 跨文件拼接，或 include 进来的 chunk），现有 `FileMap.typ` 单个路径就不够：`lines` 需要 `[输出行, .typ 行, 源文件序号]` + 一份 `sources` 列表。这正是 include 支持必须先解决的那一步 |

结论：**结构与 include 都能用，但要用起来得先付 schema v3 那笔账**（或接受"一个输出文件只来自一个源文件"的限制）。建议顺序：① 跨文档 ChunkSet（小、立刻解开多章引用）→ ② schema v3 → ③ 跟随 include。
