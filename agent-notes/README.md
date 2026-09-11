# agent-notes

**agent 持有**的项目工作记忆：调研、设计取舍、以及"哪些结论已经被实验证实"。给人看也给人写的 agent 看。

## 约定

- `research/YYYY-MM-DD-<topic>.md`：一个主题一份。结论写在最前面（TL;DR），后面才是细节。
- `decisions/`：**已经做出**的决定 + 落选的替代方案和原因（ADR 风格，追加不改写）。第一次做决定时创建。
- 原始 URL 内联在正文里，任何结论都要能点回去核对。
- 日期用本地日历日（Asia/Shanghai）。
- 事实过期就地改，并注明修正；不留两份互相矛盾的副本。
- 每条"已验证"的事实旁边写清楚用什么命令验的；没验过的标 **未验证**。

## 索引

- `decisions/2026-09-11-mvp-decisions.md` — **已拍板的 5 个决定**（场景=多文件工程，形态=纯 `.typ`，实现=Rust 原型→自举，生成物不入库，错误定位=D1）+ 落选方案与理由。
- `decisions/2026-09-11-engine-and-deps.md` — **D6 解析引擎：`typst-syntax` 为主、`typst eval` 降为 oracle**（实测：能用官方 parser 拿到精确 span，不必自己扫 fence）、**D7 依赖策略：用成熟库**（clap/notify/miette/cargo_metadata…，并推翻原 plan 的手写倾向）。
- `decisions/2026-09-11-chunk-labels.md` — **D8 chunk 命名**：Typst 的 `<...>` 不允许 `/`（实测），平面名字用 `<name>`、带目录的用 `#label("src/main.rs")`，不用自定义 `:` 编码。
- `decisions/2026-09-11-watch-contract.md` — **D9 实时同步契约**：只写字节变化的输出（mtime 不变）、语法错误不 tangle（保留上一份好产物）、事件合并、`--check-cmd` 只在真改写后跑。
- `decisions/2026-09-11-map-scope.md` — **D11 映射作用域**：`.lpmap.json` 每目录一份、只管本目录的文件（渐进式披露，映射跟着文件走，歧义报错）；schema v3 起 `lines` 为 `[输出行, 源文件行, sources 下标]`，支持一个输出文件的行来自多个源文件（多章文档）。
- `decisions/2026-09-11-output-ownership.md` — **D10 输出目录所有权**：删除只由目录里的 `.lpignore` 授权（规则即 gitignore，一次 walk 交给 `ignore` 库，匹配=保护）；`.lpmap.json` 只管行号映射，不做所有权记忆；没有声明就什么都不删；无 git 特例；`--check` 是干跑。
- `plan.md` — M0–M3 实施计划：CLI 表面、依赖预算、测试策略、自举不变量、明确不做的清单。
- `research/2026-09-11-prior-art.md` — 现有 literate programming 工具盘点（noweb/littst/Entangled/Ravel/typst-unlit/Calepin/org-babel/…），Typst 生态现状，以及 AI 时代的四篇相关工作。含"我们的差异化在哪"。
- `research/2026-09-11-typst-engine-facts.md` — **只用 typst 自己当解析器**这套架构的全部实测事实：`typst eval` / `query`、label 当 chunk 名（含 §8 的字符集限制）、raw info string 的坑、plugin 不能写文件、show rule 里的 label/link 语义。所有结论都附可复现命令。
- `research/2026-09-11-design-space.md` — 三种候选架构对比、推荐方案、正交性的边界（哪些目标语言会破坏"语言无关"）、自举带来的新约束、backlog。
- `research/2026-09-11-typst-structure-and-include.md` — 实测 Typst 文档自身的结构（heading 一等元素 + 字段）与 include 语义（内容级合并、label 全局），以及 `lp` 的两个缺口（不跟随 include、跨文档引用不成立）与补齐顺序。
- `research/2026-09-11-lazy-tangle.md` — 实时 / lazy tangle 的实测：全量重算只要 3–7ms，真瓶颈是写入抖动；`lp watch` 实现要点、FUSE/LSP 投影的天花板、复现命令。
- `../experiments/2026-09-11-chunk-spike/` — 可运行的最小验证：纯 `.typ` 同时 weave 成 PDF、tangle 成可运行的 `hello.py`，带 `--check` 漂移检测和行号映射。
- `../experiments/2026-09-11-typst-syntax-probe/` — 验证 `typst-syntax` 能给出精确 span 且文本与 `typst eval` 逐字节一致（D6 的依据）。

## 当前状态（截至 2026-09-11）

- 调研 + spike + 决策 + **M1 原型 + `lp watch`** 均已完成并合入 main。`src/` 是普通 Rust 工程（`cargo test` 全绿：3 个单元 + 16 个端到端），`lit/lit.typ` 是渲染库，`examples/demo/` 是可跑的多文件示例。
- 核心假设已验证：`.typ` 里的 fenced raw block + label 就是 chunk，`typst-syntax` 就是 tangle 的解析器（拿得到精确 span），weave 就是 `typst compile`。不需要自写 Typst 解析器，也不需要给文档加预处理语法。
- 已能跑通的完整链路（一次性）：`nix develop -c examples/demo/run.sh` —— tangle 多文件 crate → `cargo run` 输出与文档一致 → weave PDF → `--check` 无漂移 → `lp map` 定位一行 → 故意写错后把 rustc 报错回译到 `.typ:92` 并渲染源码片段 → 复原。
- 已能跑通的实时链路：`lp watch <doc> --check-cmd 'cargo build --message-format=short'` —— 只重写真正变了的文件（1 改写 / 2 原样），检查命令只在真改写后跑，诊断自动指回 `.typ`。契约见 ADR D9，实测见 `research/2026-09-11-lazy-tangle.md`。
- 下一步：`lp explain --format cargo`（cargo_metadata）、诊断列位置精确到 span、`ci.sh`（typst compile + cargo test + `tangle --check`）；之后 M3 自举。**删除语义已在 D10 定下**（`.lpignore` 目录声明 / `--check` 干跑）。见 `plan.md`。
- 主要差异化：**tangled 文件里的报错映射回 `.typ` 行号**（D5/`lp explain`）+ 生成物漂移检测。littst / typst-unlit 都不解决这两点。
- 长期目标（D3）：原型冻结为 bootstrap，工具自身源码改写成 literate `.typ` 并自举；固定点测试保证 bootstrap 与自举产物逐字节一致。
