# `pretty` 能不能解决缩进问题（2026-09-11 调研，结论：不能，也不需要）

- 起因：用户注意到我反复在缩进上出错，建议看看 [`pretty`](https://docs.rs/pretty)（Wadler/Leijen 风格布局代数）的 `DocBuilder`，特别是 `align`。
- 结论：**不适合**。我们需要的操作是"把一段逐字节的代码块的每一行前缀一个缩进"，而 `pretty` 管的是**软换行**（把文档按宽度折行）时缩进落在哪里；它对 `text` 原子内部**已经存在的换行**不负责。实测（`Arena` + `indent`/`nest`/`align`，见下）证明了这一点。
- 附带诊断：我踩的缩进坑**不在 Rust 生成侧**，而在 **Typst 渲染侧**（同一个错误犯了两次，见 §3）。

## 1. 实测（`/tmp/prettyprobe`，pretty 0.12）

```rust
arena.text("if x:").append(arena.hardline())
     .append((arena.hardline() + arena.text("line1\nline2")).nest(4).align())
// → "if x:\n\n    line1\nline2"        ← 只有第一行被缩进

arena.text("line1\nline2").indent(4)
// → "    line1\nline2"                ← 同上：内嵌换行不受影响

(arena.text("line1").append(arena.hardline()).append(arena.text("line2"))).indent(4)
// → "    line1\n    line2"            ← 两行都缩进了，但**前提是我们自己按行拆开**

let doc = arena.text("x".repeat(30)).append(arena.space()).append(arena.text("y"));
doc.pretty(10)  // → "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx y"   ← 长 atom 不折行

arena.text("a   ").append(arena.hardline()).append(arena.hardline()).append(arena.text("b"))
// → "a   \n\nb"                       ← 行尾空格与空行逐字保留
```

**要点**：`nest`/`align`/`indent` 的缩进作用在**打印机自己引入的换行**上；`text` 里的 `\n` 只是普通字符。想让每一行都缩进，唯一办法就是**我们自己把块拆成逐行 atom + `hardline`**——那正是我们已经有的那个循环（`Tangled::push` 在每行前写 indent），只是多背一个依赖，而且这个依赖的主功能（按宽度折行/重排）用在**必须逐字节一致的代码**上恰恰是绝对不能用错的。

官方文档自己也是这个意思：`nest`——"Lays out `self` with a nesting level set to the current level plus `adjust`"，例子是给**折行后的单词**加缩进；`align`——"with the nesting level set to the current column"。

## 2. 我们实际的缩进只有三处，各自都简单且正确

| 位置 | 机制 | 状态 |
| --- | --- | --- |
| 文档层（块写在列表/引用里，整体缩进） | **Typst 自己**剔除公共缩进 | 白拿，不用我们做 |
| 引用层（`<<name>>` 展开时每行按引用点缩进） | `expand_chunk` 把 `indent + local_indent` 传下去，`Tangled::push` 在每行前写一次 | 4 行代码，两个测试守着（`indentation_follows_the_reference_site`、`a_chunk_written_indented_in_the_document_is_still_dedented`） |
| 渲染层（weave 里把引用行的缩进画出来） | 包的 `ref-indent(line)`（捕获组）+ `raw(...)` | 刚修，见 §3 |

## 3. 反复出错的真实原因（不在 Rust，在 Typst 侧）

两次都是同一处：渲染 `<<ref>>` 行时写

```typ
raw(line.text.slice(0, m.start))     // m.start 是**整个匹配**的起点
```

而 `ref-re` 是 `^\s*<<…` 锚定的，`m.start` **恒为 0** → 缩进永远渲染成空。第一次在 `lit.typ` 里踩到、改了；后来渲染逻辑搬进 `lp.typ` 时**照抄了那行**，于是同一个 bug 回来了。更糟的是：第一次的修复把缩进计算放进了 `ref-indent` **helper，而渲染路径没用它**，所以 `examples/demo/run.sh` 里的检查一直是绿的——**检查的是没人调用的函数**。

结构性修法（已落地，`67db34a`）：

- `ref-re` 改成捕获缩进 `^(\s*)<<([^<>]+)>>\s*$`，用 `m.captures.at(0)`；
- `ref-indent(line)` 就是渲染路径调用的函数（不再有"测试专用 helper"）；
- run.sh 的检查因此检查的是**真代码路径**。

## 4. 什么时候才该用 `pretty`

如果哪天我们要**生成给人读的散文**——比如 `lp init` 的模板、人类可读的报告/表格、错误信息里要按宽度排版的长段落——`pretty` 是对的工具。tangle 不是：它要求"一行入、一行出、逐字节不变"，这正好是 pretty printer 的反面。
