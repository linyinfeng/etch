# Chunk 命名：两种原生写法，不发明路径编码（2026-09-11）

> **已被 D13 取代（同日）**：chunk 现在由 `lit/lp.typ` 的 `#chunk` / `#file` 声明给出，label 不再是命名机制。本文件保留为历史记录——"Typst 的 `<...>` 里不能有 `/`"这个限制今天依然成立，只是我们不再把 chunk 名字放在 label 里。

跑 M1 原型时撞上的硬约束，必须记录：**Typst 的 `<...>` label 语法只允许 `[A-Za-z0-9_.:-]`**，实测 `<src/lib.rs>` 直接是 parse error（`unclosed label`）；`/`、`,`、`+`、`[`、`]`、`#`、`%`、`=`、`*`、`@`、`$` 等全部不允许。官方文档原文：*"A label's name can contain letters, numbers, `_`, `-`, `:`, and `.`"*（<https://typst.app/docs/reference/foundations/label/>）。

这直接威胁 D1（多文件工程需要 `src/`、`tests/` 目录结构）。

## D8 — 用 Typst 自己的两种写法，不发明编码

- **决定**：
  - 平面名字用 dedicated syntax：```` ```rust ... ``` <imports> ````。
  - 需要目录（或任何 `<...>` 表达不了的字符）时用 constructor：```` ```rust ... ``` #label("src/main.rs") ````。
  - **不引入**「`:` 就是 `/`」之类的自定义编码。
- **落选**：
  - `<src:lib.rs>` → `src/lib.rs` 的 `:` 映射：语法上可行（`:` 在允许集合里），零新机制，但发明了一个非显然约定、且让真实文件名里的 `:` 变得不可达。
  - 只用 `#label("...")` 一种写法：统一但日常太长（每个 fragment 都要写 `#label("imports")`），丢掉 Typst 惯用写法。
  - 把输出路径放进独立的 `#let outputs = (...)` 声明或单独的配置 chunk：多一个"要看的第二处"，且需要语义求值（`typst eval`）才能读到，破坏「tangle 不需要 typst 二进制」这条 D6 的性质。
- **理由**：两种写法都是 Typst 原生语法、都由 `query`/`@ref`/show rule 正常识别（实测 `#label("src/lib.rs")` 会附着到前一个 code block，`it.at("label")` 拿得到）。constructor 存在的意义本来就是"名字里有特殊字符"，我们不是发明双轨，而是用满 Typst 的两条既有轨道。
- **代价**：文档里出现两种拼写（README 明确写了规则）；`lp` 的实现要多识别一种 sibling（`Hash` + `FuncCall`）。已用测试覆盖两种写法（`tests/flow.rs`）。
- **对根 chunk 判定无影响**：`is_root` 仍看"名字像不像文件名"（含 `.`），两种写法都能命中。
