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

- `handoff.md` — **接手先读这份**：项目现状、行为契约、铁规矩、已知脏点、下一步候选、环境陷阱。

- `decisions/2026-09-11-mvp-decisions.md` — **已拍板的 5 个决定**（场景=多文件工程，形态=纯 `.typ`，实现=Rust 原型→自举，生成物不入库，错误定位=D1）+ 落选方案与理由。
- `decisions/2026-09-11-engine-and-deps.md` — ~~D6 解析引擎：`typst-syntax` 为主、`typst eval` 降为 oracle~~（**修正：D6 的解析引擎部分已被 D13/D14 取代**——工具不再解析 Typst，只读声明流）、**D7 依赖策略：用成熟库**（clap/notify/miette…，并推翻原 plan 的手写倾向）。
- `decisions/2026-09-11-chunk-labels.md` — **D8 chunk 命名**：Typst 的 `<...>` 不允许 `/`（实测），平面名字用 `<name>`、带目录的用 `#label("src/main.rs")`，不用自定义 `:` 编码。
- `decisions/2026-09-11-watch-contract.md` — **D9 实时同步契约**：只写字节变化的输出（mtime 不变）、语法错误不 tangle（保留上一份好产物）、事件合并、`--check-cmd` 只在真改写后跑。
- `decisions/2026-09-11-map-scope.md` — **D11 映射作用域**：`.lpmap.json` 每目录一份、只管本目录的文件（渐进式披露，映射跟着文件走，歧义报错）；schema v5 起每份文件记的是 **chunk 区间**（`runs = [{chunk, first, last}]`，见 D14）。
- `decisions/2026-09-11-output-ownership.md` — **D10 输出目录所有权**：删除只由目录里的 `.lpignore` 授权（规则即 gitignore，一次 walk 交给 `ignore` 库，匹配=保护）；`.lpmap.json` 只管出处映射（D14 后是 chunk 区间），不做所有权记忆；没有声明就什么都不删；无 git 特例；`--check` 是干跑。
- `plan.md` — M0–M3 实施计划：CLI 表面、依赖预算、测试策略、自举不变量、明确不做的清单。
- `research/2026-09-11-prior-art.md` — 现有 literate programming 工具盘点（noweb/littst/Entangled/Ravel/typst-unlit/Calepin/org-babel/…），Typst 生态现状，以及 AI 时代的四篇相关工作。含"我们的差异化在哪"。
- `research/2026-09-11-typst-engine-facts.md` — **只用 typst 自己当解析器**这套架构的全部实测事实：`typst eval` / `query`、label 当 chunk 名（含 §8 的字符集限制）、raw info string 的坑、plugin 不能写文件、show rule 里的 label/link 语义。所有结论都附可复现命令。
- `research/2026-09-11-design-space.md` — 三种候选架构对比、推荐方案、正交性的边界（哪些目标语言会破坏"语言无关"）、自举带来的新约束、backlog。
- `research/2026-09-11-pretty-for-indentation.md` — **`pretty` 能不能解决缩进问题：不能，也不需要**（实测：`nest`/`align`/`indent` 只作用于软换行，`text` 内嵌换行不受影响；要逐行缩进仍得自己拆行）。附真正的原因：两次缩进 bug 都在 **Typst 渲染侧**（`slice(0, m.start)` 恒为空），而第一次的修复落在了渲染路径**没调用**的 helper 上，检查因此一直是绿的。
- `research/2026-09-11-source-positions.md` — **Typst 能不能给出源码行号**：脚本层/插件层**不能**（元素无 span、`location` 只有排版坐标、插件协议只传字节），只有编译器层能（`typst-syntax` 的 span，对外只经诊断）；并实测出"字符串搜索声明 token"在 demo 上会命中**散文**（第 61 行 vs 声明的第 64 行）。含四条路（不做行号 / parser 当 span 查询器 / 作者写行号 / 继续搜索）的代价表与推荐。
- `research/2026-09-11-typst-structure-and-include.md` — 实测 Typst 文档自身的结构（heading 一等元素 + 字段）与 include 语义（内容级合并、label 全局），以及 `lp` 的两个缺口（不跟随 include、跨文档引用不成立）与补齐顺序。
- `research/2026-09-11-literate-programming-thinking.md` — **LP 的思想与各方立场**（结论在前）：Knuth 的四条可分开表态的主张、noweb 的语言无关路线、notebook 的分界、文档生成派的胜利、Nørmark 的第三条路、"LP 已死/被吸收"、AI 时代的两面论证；附证据强度表（哪些是实测、哪些只是证词、哪些没找到证据）。配套的 agent skill 在 `../.agents/skills/literate-programming/`。
- `decisions/2026-09-11-no-positions.md` — **D14 行号映射不做了**（用户规矩："活不能优雅地做 → 不做"）：Typst 脚本层拿不到源位置，要行号只能搜索源码或重新解析 Typst；改成 **chunk 级出处**（chunk 区间），删掉 `locate.rs`/`source.rs` 与 span 报错。
- `decisions/2026-09-11-self-hosting-layout.md` — **D15 自举布局（Stage 1 已落地）**：crate 留在仓库根、根就是 `--out`、`bootstrap/` 是冻结种子；达成标准（`--check` 等于冻结前手写源码）与永久不变量（自己构的二进制 `--check` 绿，`tests/self.rs`）分开；`<<name>>` 独占一行的撞车改我们的夹具（`concat!`）而不加转义语法。
- `decisions/2026-09-11-declared-chunks.md` — **D13 声明式 chunk（取代 D8 的 label 命名与 D12 的四层搜索）**：文档 import `lit/lp.typ` 并用 `#chunk`/`#file` 声明；工具只读声明流，位置靠精确 token 查找。
- `decisions/2026-09-11-typst-is-the-authority.md` — **D12 架构定案**：chunk 集合/顺序/文本由 **Typst 求值**给出（wrapper 埋点 + `typst eval`，不改用户文档），源位置由**四层纯搜索定位器**给出（Literal / Template / Generated / Nowhere）；静态分析被否决（图灵完备面前构造上就是错的）。含实测的两个决定性 case 与代价（typst 成为硬依赖、文档必须能求值）。
- `research/2026-09-11-lazy-tangle.md` — 实时 / lazy tangle 的实测：全量重算只要 3–7ms，真瓶颈是写入抖动；`lp watch` 实现要点、FUSE/LSP 投影的天花板、复现命令。
- `../experiments/2026-09-11-chunk-spike/` — 可运行的最小验证：纯 `.typ` 同时 weave 成 PDF、tangle 成可运行的 `hello.py`，带 `--check` 漂移检测和行号映射。
- `../experiments/2026-09-11-typst-syntax-probe/` — 验证 `typst-syntax` 能给出精确 span 且文本与 `typst eval` 逐字节一致（D6 的依据）。

## 当前状态（截至 2026-09-11，`5efc543`）

> **修正（D13/D14 之后重写）**：原版这一节还写着 "`typst-syntax` 就是 tangle 的解析器" 与 "报错映射回 `.typ` 行号是差异化"，两条都已被推翻。以 `handoff.md` 为准。

- 调研 + spike + 决策 + **M1 原型 + M2（`lp watch`、输出目录所有权、chunk 级出处）+ 自举 Stage 1** 均已完成并合入 main。`cargo test` 全绿 48 个（6 单元 + 42 端到端）；`lit/lp.typ` 是包（渲染 + 声明），`examples/demo/` 是可跑的多文件示例。
- **自举 Stage 1（D15）**：`self.typ` 逐字节复现整个 crate，`Cargo.toml`/`src/`/`tests/` 是生成物（gitignore），`bootstrap/` 是冻结种子；fresh clone 先跑种子再 `tangle self.typ --out .`。Stage 2（抽公共 chunk、加散文）未做，见 `plan.md`。
- 核心假设（D13/D14 定稿）：**chunk 由文档声明**（`#chunk`/`#file`），工具只跑 `typst eval 'query(<lp-decl>)'` 读回声明流，**从不解析 Typst**；weave 就是 `typst compile`；出处是 **chunk 级**（哪个声明、在它里面第几行），**不记 `.typ` 行号**。
- 已跑通的一次性链路：`nix develop -c examples/demo/run.sh`（tangle 多文件 crate → 构建运行 → weave PDF → `--check` → `lp map` → 用 `lp explain` 把 rustc 报错回译到 chunk → 复原）。
- 已跑通的实时链路：`lp watch <doc> --check-cmd 'cargo build --message-format=short'` —— 只重写真正变了的文件，检查只在真改写后跑，诊断自动指回 chunk。契约见 ADR D9，实测见 `research/2026-09-11-lazy-tangle.md`。
- 下一步候选与代价见 `handoff.md` §6（cargo JSON 后端 + `ci.sh` 是小尾巴；自举 M3 是大头）。**删除语义已在 D10 定下**（`.lpignore` 目录声明 / `--check` 干跑）。
- 差异化：**chunk 级出处 + 生成物漂移检测与归属**——报错给到"哪个声明、在它里面第几行"，chunk 名一步 `rg` 到声明；littst / typst-unlit 都不解决这两点。
- 长期目标（D3）：原型冻结为 bootstrap，工具自身源码改写成 literate `.typ` 并自举；固定点测试保证 bootstrap 与自举产物逐字节一致。
- **agent skill（新增）**：`.agents/skills/literate-programming/` —— `SKILL.md`（纪律 + lp 机制 + 错误对照表）+ `references/example.md`（一个真的 tangle 过、跑过的两文件例子）+ `references/thinking.md`（什么时候值得用 LP、反方批评、证据强度）。pi 与其他支持 Agent Skills 的 harness 会自动发现它。
