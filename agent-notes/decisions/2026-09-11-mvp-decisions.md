# MVP 决策（2026-09-11）

用户拍板的五个决定。格式：决定 / 落选 / 理由 / 影响。追加不改写；后续推翻就新开一份并注明取代关系。

---

## D1 — 首要场景：多文件库/工程

- **决定**：先把"多根 chunk、目录结构、CI 集成、错误定位"这条线做透。个人文档型项目与 agent 工作流是自然受益者，不做特化。
- **落选**：个人文档型项目优先（weave 体验优先）；agent 工作流优先（先做可查询 chunk 图）。
- **理由**：多文件工程把最难的部分（多根/依赖/报错回译/漂移检测）逼出来；先做简单的会导致核心机制迟迟不验证。
- **影响**：MVP 必须支持一个文档多个根 chunk（`src/foo.rs`、`tests/x.rs` 这种 label）；`--check`、`lp map`/`lp explain` 属于 M1，不是"以后再补"。

## D2 — 主文件形态：方案 A（纯 `.typ`）

- **决定**：主文件是合法 Typst 文档，chunk = 带 label 的 fenced raw block，weave = `typst compile`，tangle 用 `typst eval` 取 chunk。
- **落选**：独立 noweb 风格格式 + 预处理器（方案 B，即 littst 路线）；A+B 双支持。
- **理由**：保留 typst-lsp / typst-preview / `typst compile` 的完整生态；不重新发明 markup；不维护第二个解析器。
- **代价（接受）**：chunk 名依赖 Typst label（要注意 label 唯一性/重复宽容问题，见 engine-facts §4）；`<<ref>>` 是纯文本约定，Typst 不校验，tangle 必须严格报错。

## D3 — 实现语言：Rust 原型 → 冻结为 bootstrap → 自举

- **决定**：先手写 Rust 原型（把 spike 验证过的语义做扎实）；原型达标后 **冻结为 bootstrap**，工具自身的源码改写成 literate `.typ` 文档并自举（工具用自己 tangle 自己的 `src/*.rs`）。目标语言始终任意。
- **落选**：Python 原型（最快，但不满足自举）；Node/TS（与 pi 生态一致但同样不满足自举）；Python 先做后 Rust 重写。
- **理由**：原型就是"种子的手写版本"，自举后它只负责生成同一个 crate；固定点可测（见 `../plan.md` 的自举不变量），不需要长期维护两套。
- **影响**：
  - 原型阶段就要**避免依赖语言无关性之外的假设**，否则自举时文档里会出现"工具自身的特殊逻辑"。
  - `lp explain` 的第一个后端必须是 **rustc/cargo**（自举时每天用）。
  - 仓库布局要提前为自举留位置（`bootstrap/` 与 `src/` 共存期）。

## D4 — 生成物不入库 + watch + CI check

- **决定**：tangled 源码 gitignore；本地/agent 编辑走 `lp watch` 自动重生成；CI 跑 `lp tangle --check`，漂移即失败。
- **落选**：生成物入库 + CI check；两种都做成配置。
- **理由**：唯一真相明确；避免 AI agent 去改生成物而不是文档——这是 AI 时代 LP 最现实的失败模式。
- **影响**：clone 后必须先 tangle 才能编译；CI 里需要 typst（`nix shell nixpkgs#typst`）；`lp watch` 从"nice to have"变成 M2 必做。

## D5 — 错误定位：D1（sidecar map + `lp explain`）

- **决定**：tangle 时产出 sidecar 映射（每个输出行 → `.typ` 行，spike 已实现）；`lp map` 做纯查表，`lp explain` 负责把常见诊断格式（第一个是 rustc JSON）翻译成 `.typ` 位置。**不注入行指令。**
- **落选**：注入 `#line`/`//line` 语言行指令；D1+D2 都做。
- **理由**：语言无关（不需要语言表，不污染产物，`--check` 能保持产物与"手写文件"逐字一致）；D2 只能覆盖部分语言（Python/JS/Java 没有行指令），而且要维护语言知识，与"正交"冲突。将来若某个语言生态强烈需要，可以作为可选增强加回（数据表驱动）。
- **影响**：`lp explain` 需要一小组"诊断格式提取器"（rustc JSON、`file:line:col`、Python traceback），它们是数据不是算法；用户的 IDE/编辑器集成要依赖 `lp map`。
