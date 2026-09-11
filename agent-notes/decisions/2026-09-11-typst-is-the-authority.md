# Typst 求值即权威，定位靠搜索（2026-09-11）

- 决策来源：用户判定"利用 typst 元数据才是对的，因为 typst 是图灵完备的，我动态生成代码块你怎么解决？""而不是力大砖飞去静态分析 typst"。
- 本 ADR 记录**方向与已落地的第一块**（`metadata.rs` + `locate.rs` + `lp metadata`）；把 `tangle` 切到这条管线是紧接着的下一步。

## 实测（决定性的两个 case）

```typ
#for i in range(3) [
  #raw("print(" + str(i) + ")", lang: "py", block: true) #label("built-" + str(i))
]
```

```json
[{"label":"built-0","lang":"py","text":"print(0)"},
 {"label":"built-1","lang":"py","text":"print(1)"},
 {"label":"built-2","lang":"py","text":"print(2)"}]
```

- **源文件里根本没有 `print(0)` 这一行**（只有生成它的那行代码）。静态分析看到的是**模板**，不是**结果**；这类 chunk 我们过去会**看不见**——而它不是边缘 case，是"图灵完备"的直接后果。
- 同一个机制还白拿了：`#include` 的内容（Typst 是内容级合并）、`#if sys.inputs` 分支、函数产出的块、动态 label。
- 还有一条关键验证：**wrapper 装的 show rule 不会被文档自己的 show rule 吃掉**（我们的 `lit.typ` 就是 `#show raw` 的风格化规则）——两条规则叠加，元数据事件照样完整产出。
- 备选方案也测了：不装 show rule，只用 `location()` 排序 `(page, y)` 也能重建文档顺序（万一将来某条用户规则把 raw 整个换掉，还有这条路）。

## 拿不到的东西：源位置

Typst **不暴露 span**（`query` 结果没有行列；`location()` 是排版位置）。而"生成行 → `.typ` 行"正是本工具的核心。所以定位必须**另找办法**，且不能是"用 Rust 重实现 Typst 语法"——那正是用户否决的力大砖飞。

## D12 — 两段式：Typst 决定"是什么"，搜索决定"在哪里"

- **决定**：
  1. **chunk 集合 / 顺序 / 文本 / 语言，一律由 Typst 求值给出**：生成 wrapper（只 `#include` 用户文档，**不改用户的文件**）+ show rule 埋点（`raw` 块与 `heading` 各发一条 `#metadata`，带自增序号）+ `typst eval 'query(<lp-event>).map(e => e.value)'` → 有序事件流 JSON。顺序的是**文档自己的顺序**，不再是"命令行文件顺序"这种我们的猜测。
  2. **源位置用一个纯搜索的定位器**（`locate.rs`），四层，逐层降低可信度：
     - **Literal**：源里能找到该 label，且它上方到 fence 之间的内容（去掉公共缩进后）与该 chunk 的文本**逐字相等** → 精确（这是绝大多数情况）。
     - **Template**：label 是运行时拼的，但**文本**在源里出现过 → 所有这类 chunk 都指向那段模板（读者要改就去那里）。
     - **Generated**：连文本都不存在（代码拼出来的），但 label 的**最长字面前缀**（`built-`）留在源码里 → 指向生成它的那一行。
     - **Nowhere**：什么都不匹配 → **如实说"没有字面位置"**，绝不编一个行号出来。
  3. **定位器不许理解 Typst**：只做去缩进、逐行比对、找 `<label>` / `#label("label")` token。解析器要跟着 Typst 版本走，搜索不用。
- **落选**：
  - 静态分析（现状）：图灵完备面前**构造上就是错的**（上例看不见或看错），而且等于用 Rust 重实现一份 Typst 语义，永远追不上。
  - 在 Rust 里跟随 `#include`：那是把 Typst 的合并语义实现一半——`#include` 之外还有 `#for`/`#if`/函数产出。
  - 要求用户在文档里写额外元数据（例如让 `lp` 的函数包住每个块）：这会把"任何合法 Typst 文档"退化成"必须按我们的规范写"。
  - 用 `location()` 排序替代 show rule 埋点：可行（已实测），但比事件流脆（受分页/多栏影响）；留作 show rule 被吃掉时的后备。
- **代价（如实记）**：
  - **`typst` 成为 tangle 的硬依赖**（`LP_TYPST` 或 PATH）。这修正了 D6 的"tangle 不需要 typst"——那条只适用于纯静态路线。
  - **文档必须能求值**才能 tangle：半写状态不再由我们的语法门拦截，而是 Typst 自己的诊断（更准，也更严格）。这实际上**强化**了 D9 的"半写文档不 tangle"。
  - 每轮多一次 `typst eval`（实测 ~36ms 量级），watch 回路仍远低于 200ms 去抖窗口。
  - 动态生成的 chunk 在映射里**没有精确行号**：`lp map` / `lp explain` 要能说"这一行由文档代码生成，位置是 `file:line`（生成器）或未知"，而不是给一个错行。
- **影响 / 待办**：
  - `tangle::plan()` 改为：事件流给 chunk，`locate` 给位置，`<<ref>>` 展开与缩进语义照旧（作用在**求值后**的文本上）。
  - `Block.file`/`FileText` 保留（位置仍要指到具体文件），但 `Doc` 不再需要解析结果；`typst-syntax` 依赖可以从 Cargo.toml 里删掉。
  - 映射 schema 需要表达"无字面位置"（`lines` 的 typ/源下标用 `null`，schema v4）。
- **已落地**：
  - `metadata.rs`：wrapper（只 `#include`）+ `typst eval 'query(raw.where(block: true))…'`。
  - `locate.rs`：四层定位器（Literal / Template / Generated / Nowhere），6 个单元测试覆盖缩进块、重复文本、运行时 label、代码构造、无匹配。
  - `tangle::plan` 已切到这条管线：chunk 集合/顺序/文本/语言**全部**来自求值；位置来自定位器；`<<ref>>` 展开与缩进照旧作用在求值后的文本上。
  - **`typst-syntax` 已从依赖里删除**——工具对 Typst 的全部"理解"就是 Typst 自己 + 一个搜索。
  - 映射 schema v4：`lines` 为 `[输出行, 源文件行|null, sources 下标|null]`，`null` 表示"这一行由文档代码生成，没有字面位置"。
  - `lp metadata <doc>...` 调试命令；`tests/metadata.rs` 覆盖 include、循环、代码构造、**被样式 show rule 吞掉的块**、以及文档求值失败。
  - 实测代价：demo 文档一次完整 `tangle`（含一次 `typst eval`）**77ms**（debug 构建），watch 的 200ms 去抖窗口仍然宽裕。

### 落地时踩到的坑：show rule 埋点是脆的

第一版埋点用 `#show raw.where(block: true)` + counter 发 `#metadata` 事件。它在最小例子上工作，**但在自己的 demo 上全丢了带 label 的 chunk**：`lit.typ` 的风格化规则把带 label 的 raw block **替换**成一个渲染好的 `block(...)`，于是埋点再也看不到这个元素（未标注的块因为那条规则 `return it` 反而还在）。教训写在这里，因为它推翻了 T1 的乐观结论：

- **T1 的结论只在那条 show rule 仍然返回 raw 元素时成立**（`block(...)[#it]`，元素仍在输出里）；一旦规则**消费**元素（我们的 `lit.typ` 就是），埋点即失效。
- 因此改成**直接 query 元素树**（`query(raw.where(block: true))`）：show rule 只影响渲染，不改可查询的文档树。
- 代价：失去"事件流里 chunk 与 heading 交错"的能力（那是 counter 埋点给的东西）。需要分节归属时，用 `location()` 按 `(page, y)` 排序重建顺序（已验证可行），或者分别 `query` 两个流后按位置合并。这是**将来**做分节功能时才需要的东西，不为它保留一个脆的机制。
