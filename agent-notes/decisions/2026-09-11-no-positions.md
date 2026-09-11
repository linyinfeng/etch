# 行号映射不做了：优雅是准入条件（2026-09-11）

> 用户立的规矩（原文）：**"活不能优雅地做 --> 不做"**。这条是准入条件，不是偏好：任何功能的实现路径如果必须靠启发式、字符串搜索、或与 Typst 版本耦合的重复解析才能成立，那么**这个功能就不做**，而不是"先脏着做出来再优化"。

## D14 — 删掉行号映射（lpmap），保留 chunk 级出处

- **背景**：`lp` 的核心卖点曾是"生成物里的报错能指回 `.typ` 的第几行"。实现它有两条路，都不优雅：
  - **字符串搜索**（当前实现）：实测在**自己的 demo** 上就出错——散文第 60 行引用 `` `#chunk("math-items", …)` ``，真声明在 64 行，工具把输出行指到了散文（`demo.typ:61`）。任何"在正文里引用自己写法"的文档都会中招。
  - **链接 Typst 的 parser crate 拿 span**：精确，但那是把 Typst parser 放回工具里（我们刚花力气删掉），且 crate 版本必须与 `typst` 二进制对齐。
  调研见 `../research/2026-09-11-source-positions.md`：Typst **脚本层与插件层拿不到源位置**（元素无 span 字段、`location` 只是排版坐标、插件协议只传字节），只有编译器层有，且只经诊断暴露。
- **决定**：
  1. **不做行号映射。** `.lpmap.json` 不再记 `[输出行, .typ 行]`；`lp map` 不再报 `.typ:行`。
  2. **出处降到 chunk 级，而且它是白拿的**：展开时本来就知道每段输出行来自哪个声明、在该声明内第几行，所以记 **chunk 区间**（`runs`：`chunk` / `first` / `last`）。`lp explain` 因此输出 `↳ chunk ⟪print-results⟫, line 1 of 2`——agent 一句 `rg '#chunk\("print-results"'` 就跳到声明。
  3. **连带删除**：`locate.rs`（整条 token 搜索）、`source.rs` 的 include 扫描与 `FileText`、以及 `diag.rs` 的 span 支持（没有源位置，错误就是消息 + help）。工具对 Typst 的全部"理解"只剩：跑一次 `typst eval` 读声明流。
  4. **parser 路线明确搁置**（不是待办）：接口（`runs`）已留好，将来若真要行号，替换实现即可，但那要先破"不解析 Typst"这条。
- **代价（如实）**：
  - 报错不再带 `.typ` 源码片段与 `file:line`：引用悬空/成环/空 chunk 的错误变成"chunk ⟪X⟫ 第 N 行" + 该行原文（信息仍在，只是不含位置）。
  - 编辑器集成若想做"跳到定义"，需要按 chunk 名搜索（一次精确 grep），而不是直接用行号。
- **收益**：少一个依赖方向（不与 Typst 版本耦合的解析）、少一套启发式、少一个易错的持久化 schema；工具显著变小（删 300+ 行）。
- **回归**：`tests/flow.rs` 的 map/explain 改断言 chunk+偏移；`tests/metadata.rs`/`owned.rs`/`lazy.rs` 去掉 `.typ:行` 断言；`locate.rs` 的 6 个单元测试随文件删除。
