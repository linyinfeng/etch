# 声明式 chunk：文档说它有什么，工具只找位置（2026-09-11）

- 决策来源：用户否决"用搜索定位源码行"（"如果是搜索，那太脏了，如果不能优雅地做到，那就不要做"），并提出可以接受**文档安装一个 Typst 包、用特殊的指令**。
- 本 ADR 记录这条路线，并**取代**：
  - D8 的 chunk 命名（用 Typst label 当名字）——label 现在与 chunk 无关；
  - D12 的"四层启发式搜索定位"——那四层里只有第一层是对的，其余是在没有锚点时不得已的猜测。

## D13 — chunk 由声明给出，声明自己就是位置锚点

- **决定**：
  1. **包 `lit/lp.typ`** 提供两个声明函数，代码块作为参数传入：
     ```typ
     #import "lit/lp.typ": chunk, file, rule
     #show: rule

     #chunk("imports", ```rust
     use std::fmt;
     ```)

     #file("src/main.rs", ```rust
     <<imports>>
     fn main() {}
     ```)
     ```
     `#file(path, …)` 是根 chunk（path 就是要写的文件），`#chunk(name, …)` 是片段。包把 `(lp, name, lang, text)` 作为 `#metadata` 发出来，并顺带负责渲染（带标题的块 + 引用标记），所以文档不需要任何样式化 show rule。
  2. **工具只读声明流**：`typst eval 'query(<lp-decl>).map(d => d.value)'`（经只 `#include` 用户文件的 wrapper）。名字、语言、正文**全部来自求值**——`#for`/`#if`/函数/`#include` 生成的 chunk 一视同仁，`typst-syntax` 从依赖里删除。
  3. **位置 = 声明自身的精确 token 查找**：找 `#file("src/main.rs"` / `#chunk("imports"`（也接受 `#lp.chunk(` / 单引号写法），然后按行计数得到正文首行。这是**查表**：`locate.rs` 里没有一行知道 fenced block 长什么样，正文也根本不从源码读。
  4. **只有一种退化**：名字是运行时拼的（`#chunk("part-" + str(i), …)`），字面 token 不存在，则用**最长的字面前缀**定位到**生成它的那行代码**（读者/agent 要改的就是那里）；仍然匹配不到就如实说"由文档代码生成"，**不编行号**。
  5. 没有声明就报错并给出写法（而不是退回启发式）。
- **落选**：
  - **用 Rust 静态分析 Typst**（`typst-syntax`，本项目最早的做法）：图灵完备面前构造上就是错的（实测：循环里 `raw(...)` 造出的 chunk，其正文在源文件里一行都没有）。等于长期维护一份 Typst 语义的复制品。
  - **show rule 埋点**（`#show raw` + counter 发事件）：最小例子上可行，但**样式化规则一旦消费元素**（我们自己的 `lit.typ` 就是）埋点即失效——实测 demo 上带 label 的 chunk 全丢，只剩未标注的示例块。
  - **四层启发式搜索**（D12 的 Literal/Template/Generated/Nowhere）：在"chunk 只是带 label 的 fenced block、没有别的锚点"的前提下不得已的猜测（去缩进比对、找 fence、前缀猜测）。声明一旦存在，这些都不需要了。
  - **要求作者手写行号**：不可维护；而声明 token 是作者本来就要写的东西，零额外负担。
- **代价（如实记）**：
  - 文档必须 import 我们的包、用我们的指令。写纯 Typst 的人会看到 `#file("src/main.rs", ```…```)` 这种形态——它同时是"这是一段代码、它属于哪个文件"的显式表达，作者本来也需要表达这件事。
  - 正文以**参数**方式传入（不是 `[...]` 内容块），因为需要 `code.text` / `code.lang`；代价是渲染要用一个 `rule` show rule 做引用标记（纯样式，不影响语义）。
  - 仍然是"文档必须能求值"+"`typst` 是硬依赖"（D12 已记）。
- **影响**：`Block.root` 来自声明类型（不再有 `is_root` 的文件名启发式）；`ChunkSet::roots()` 按声明顺序取；`lit/lit.typ` 删除（渲染并入 `lit/lp.typ`）；映射 schema 仍是 v4（位置可为 `null`）。
- **回归**：`src/locate.rs` 的 5 个单元测试（字面声明、同行代码、同名取用顺序、运行时名字指回循环、无匹配不编行号）；`tests/metadata.rs`（样式化 show rule 不会藏掉 chunk、章节 include、循环生成的 chunk、文档求值失败、没有声明时的报错）；其余 38 个端到端测试全部改写成声明语法。
