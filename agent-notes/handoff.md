# 接手说明（handoff）— 2026-09-11，截至自举 Stage 1（`5efc543`）

> 这是**快照**，会过期。行动前先 `git log --oneline -5`、读 `agent-notes/README.md`（索引 + 当前状态），细节都指向 `research/` 与 `decisions/`。

## 0. 30 秒

- **是什么**：`lp` —— 基于 Typst 的 literate programming 工具。同一个 `.typ` 文档既是可排版的文档（weave = `typst compile`），也是多种目标语言源码的唯一真相（tangle = `lp tangle`）。与目标语言正交：工具里没有任何目标语言知识。
- **仓库**：`~/Projects/literate`（分支 `main`）。devshell 带 `typst 0.15.1` + `cargo 1.97`：`nix develop -c <cmd>`。
- **自举 Stage 1 已落地（ADR D15）**：`lp.typ` 是唯一真相；根 `Cargo.toml`/`src/`/`tests/`/`.agents/`（含 skill）是**生成物**（gitignore）；`seed/` 是**冻结种子**。所以 clone 后 `src/` 根本不存在，先跑种子：

  ```sh
  nix develop -c cargo build --manifest-path seed/Cargo.toml   # 种子
  nix develop -c ./seed/target/debug/lp tangle lp.typ --out . # 生成 crate
  nix develop -c cargo test                                          # 48 个，需要 typst
  ```

- **已有生成物时**先跑这三件事：`nix develop -c cargo test`（51 个，**需要 typst**）、`nix develop -c examples/demo/run.sh`（端到端）、`nix develop -c ./target/debug/lp tangle lp.typ --out . --check`（自复现，必须绿）。
- **顺序自由（D18，推翻 D16）**：声明顺序由论证决定——骨架在前、或“先讲想法与片段、最后组装”，都正当；fence 的 `lang` 只是数据（高亮/映射），不做一致性检查。工具只管**机制**（引用可解析、无环、非空、`--check`、输出目录被解释）；**“重思路、渐进式披露、逻辑自洽”全部靠 skill**（写作者）。

## 1. 它现在是什么（行为契约）

| 问题 | 谁回答 | 机制 |
| --- | --- | --- |
| 有哪些 chunk、什么顺序、文本、语言 | **Typst 求值** | 文档 import `lit/lp.typ` 用 `#chunk(name, ```…```)` / `#file(path, ```…```)` **声明**；工具 `typst eval 'query(<lp-decl>)'` 读回来。`#for`/`#if`/函数/`#include` 生成的 chunk 一视同仁 |
| `<<name>>` 展开、缩进、悬空/环/空 chunk 报错 | `lp`（`tangle.rs`） | 纯文本替换 + 每行缩进；作用在**求值后**的文本上。要原样展示 `<<name>>` 独占一行用 `@<<name>>`（D17） |
| 每行输出从哪来 | `lp`（`map.rs`，schema v5） | **chunk 区间**：`runs = [{chunk, first, last}]`，每目录一份 `.lpmap.json`。**没有 `.typ` 行号**（见 §2） |
| 输出目录里的东西归谁 | `lp`（`status.rs`） | 三类：**produced**（`#file` 声明写的）/ **declared**（`.lpignore`，规则即 gitignore、**匹配=保护**）/ **unaccounted**（都不是 → `tangle` **报错**；只有 `lp unaccounted --delete` 才删） |
| weave | `typst compile` | 包同时负责渲染（带标题的块 + 引用标记），文档不需要样式 show rule |

**布局契约（D15）**：`lp.typ` 声明整个 crate；`seed/` 是冻结种子（tracked，永不重新生成）；根 `.lpignore` 列出所有手写资产，因为 `--out` 就是仓库根（每次 `tangle` 走整棵树，实测 0.82s 含一次 typst 求值，8477 个 `target/` 文件，walk 不是瓶颈）。

`lp watch`：`notify` + 去抖；**只写变化的字节**（mtime 不动）；**文档不能求值就跳过本轮并保留上一份好产物**；`--check-cmd` 只在真改写后跑并把诊断回译成 chunk。契约见 `decisions/2026-09-11-watch-contract.md`。

## 2. 铁规矩（先读这一节再动手）

1. **优雅是准入条件**：**活不能优雅地做 → 不做**。任何功能若只能靠启发式搜索、字符串匹配源码、或与 Typst 版本耦合的重复解析实现，就**不做**，而不是先脏着做出来（`AGENTS.md` 里）。
2. **不解析 Typst**：工具对 Typst 的全部理解 = 跑一次 `typst eval` 读声明流。不要引入 `typst-syntax` 之类去"理解文档"。
3. **不做行号映射**：不是待办，是**已决定不做**（Typst 脚本层拿不到源位置；要行号就得破规矩 1/2）。见 `decisions/2026-09-11-no-positions.md` 与 `research/2026-09-11-source-positions.md`。
4. **正交性**：算法里不得出现目标语言知识；语言差异只能是数据表。
5. **生成物不入库**：`examples/demo/build/` 与**工具自己的 crate** 都是生成物；`.typ` 是唯一真相。**手改 `src/`/`tests/` 会被 `tests/self.rs` 抓住**——要改工具就改 `lp.typ`。

## 3. 决策索引（一句话版）

| ADR | 决定 |
| --- | --- |
| `mvp-decisions.md` | 场景=多文件工程；形态=纯 `.typ`；实现=Rust→自举；生成物不入库；错误定位=D1（已被 D14 取代） |
| `engine-and-deps.md` | D6 引擎（解析部分由 D13 取代）；D7 用成熟库，不手写已被解决的问题 |
| `chunk-labels.md` | ~~label 当 chunk 名~~ → 被 D13 取代（保留字符集限制的历史记录） |
| `output-ownership.md` | D10 删除只由 `.lpignore` 声明授权；map 不再是账本；`--check` 是干跑 |
| `watch-contract.md` | D9 只写变化字节 / 不 tangle 半写文档 / 事件合并 / check 融合 |
| `map-scope.md` | D11 每目录一份 map；v5 起记 chunk 区间 |
| `typst-is-the-authority.md` | D12 chunk 的权威是 Typst 求值；**含 show rule 埋点为何脆的实测** |
| `declared-chunks.md` | D13 **声明式 chunk**：`#chunk`/`#file`，声明自带 name/lang/text |
| `no-positions.md` | D14 **删掉行号映射**，出处降到 chunk 级；`locate.rs`/`source.rs` 删除 |
| `self-hosting-layout.md` | D15 **自举布局**：根即 `--out`、`seed/` 冻结种子、达成标准与永久不变量分开、引用撞车改夹具不加语法 |
| `document-invariants.md` | ~~D16 结构不变量~~ → **已被 D18 推翻**（留档：边界划分与“为什么推错”） |
| `reference-escape.md` | D17 **转义**：`@<<name>>` 输出字面量；skill 进文档后必须能展示引用语法 |
| `order-is-free.md` | D18 **顺序自由**：不检查声明顺序、不检查 lang；工具管机制，论证归写作者 |

## 4. 不许回头做的事（都踩过，附证据）

| 别做 | 为什么 |
| --- | --- |
| 用 Rust 静态分析 Typst（`typst-syntax`） | 图灵完备下**构造上就是错的**：循环里 `raw(...)` 造出的 chunk，其正文在源文件里一行都没有（实测，见 D13） |
| 用 `#show raw` 埋点收集 chunk | 样式化规则一旦**消费元素**就失效——我们自己的包就是这么渲染的，demo 上 chunk 曾全丢（实测，见 D12） |
| 在源码里搜索声明 token 定位行号 | 实测在**自己的 demo** 上指到了散文（第 61 行 vs 声明的第 64 行），见 `research/2026-09-11-source-positions.md` |
| 自己实现 `.lpignore` 的匹配/优先级 | `ignore` crate 的 walker 就是干这个的（`status.rs` 已交回给它） |
| 往生成物注入行指令 / `#line` | 语言无关性 + `--check` 要逐字一致；已被 D5 否掉 |
| 手改 `src/`、`tests/` 或让 `seed/` 跟着文档更新 | 前者 `tests/self.rs` 立刻红；后者等于把种子变成第二份"生成物"，工具坏掉时没有可信起点（D15） |
| 现在就给引用加转义语法 | 撞车只出现在"目标语言文件里恰好有一行独占的 `<<name>>`"，我们自己的 4 处是测试夹具，已用 `concat!` 解决；升级路径（行首 `@`）记在 D15，真有人需要再做 |

## 5. 当前状态与已知脏点

- **测试 49 个**（7 单元 + 19 flow + 5 lazy + 7 metadata + 10 owned + 1 self），fmt/clippy 干净，`examples/demo/run.sh` 全绿。
- **工具只管机制**：引用可解析、无环、非空、`--check`、输出目录被解释；顺序自由、lang 不检查（D18）。引用转义 `@<<name>>`（D17）。
- **skill 也是生成物**：`.agents/skills/literate-programming/`（SKILL.md + 两个 reference）由 `lp.typ` 声明；改 skill = 改文档。skill 的第一句是**文档的主语是思想、代码是证据**，接着八条纪律（每节是一个主张 / 代码是证据 / 写 rejected 与为什么 / 散文不是 caption / 名字是想法不是实现 / 一个名字一个概念 / 说出未做到的部分 / 先改思路、最后读一遍），然后才是 lp 机制。
- **自举 Stage 1 已验**：种子 `seed/target/debug/lp tangle lp.typ --out . --check` 全 ok，且 `diff -r seed/{src,tests} .` 逐字节相同；`tests/self.rs` 守永久不变量（自己构的二进制自复现）。
- 规模：`lp.typ` 3778 行（17 个根 chunk：Cargo.toml + `src/` + `tests/` + skill 三个文件）；生成的 `src/` 1890 行 + `lit/lp.typ` 86 行；`seed/` 是同一批字节的冻结副本。
- 上一轮审计后**剩余**的脏点（按程度）：
  1. `metadata.rs` 的 `QUERY` 字符串与包之间是隐式契约（字段名两处各写一遍；serde 会兜住缺字段，未知 kind 已在边界报错）——低风险，值得一句注释/一个断言；
  2. `lp.typ` 是**转写产物**：一个文件一个根 chunk，没有共享、没有散文（Stage 2 的活，不是 bug）；
  3. `seed/Cargo.toml` 的 `[workspace] exclude = ["experiments/*"]` 现在是相对 `seed/` 的死路径——无害（种子是冻结文件），别顺手"修"；
  4. `status.rs` 的 `compress` 用字符串拼路径、`main.rs` 的 `list` 重复 `plan()` 的一小段、`examples/demo/run.sh` 用 `sed -i` 改生成物演示报错回译——都是展示/演示层，建议留。

## 6. 下一步候选（带代价）

| | 内容 | 代价 |
| --- | --- | --- |
| A | 自举 Stage 2：把 `lp.typ` 里重复片段抽成 `#chunk` 共享、加散文、按章节拆 | 中；**产物不再等于 `seed/` 是预期结果**，靠 `tests/self.rs` + `cargo test` 守 |
| B | `lp explain --format cargo`（`cargo_metadata` 解 `--message-format=json`） | 小；`--message-format=short` 已经能走通通用后端，所以不急 |
| C | 分节归属：用 `location()` 按 `(page, y)` 合并 heading 流与声明流（已验证可行） | 中；注意 D12 的教训——别再依赖 show rule |
| D | "章节即文件"：heading 带 `<src/main.rs>`，该节内声明的 chunk 都归这个文件 | 语义变化，需新 ADR |
| E | `lit/lp.typ` 发布成 `@preview` 包（目前只能 `#import "相对路径"`） | 小-中，需要包名与版本策略 |

**明确不做**：`ci.sh`（用户 2026-09-11："没自举做什么 ci"）——自举稳住了再谈，届时跑的就是 §0 那三步 + `--check` + `run.sh`。

## 7. 环境陷阱

- **`typst` 必须在 PATH**（或 `LP_TYPST`）：tangle 靠它读声明，`cargo test` 也需要 → 一律 `nix develop -c ...`。
- **fresh clone 不能直接 `cargo test`**：`src/` 是生成物，先按 §0 跑种子那两步。
- **flake 只看 git 已跟踪的文件**：新建/改 `flake.nix` 后要先 `git add`，否则 `nix develop` 报 `not tracked by Git`。
- **`.lpignore` 语义与 `.gitignore` 反向**：匹配 = **保护**（"要保留什么"的清单），不是"忽略"。控制文件只有 `.lpignore` 与 `.lpmap.json`，**没有 git 特例**，点文件是普通内容。新增顶层文件（编辑器临时文件、新工具目录）要顺手声明，否则 `tangle` 报"未处置"——`.agents/` 曾经就因此报错。
- **改写 `lp.typ` 里的文件内容时注意两件事**：正文里出现独占一行的 `<<name>>` 必须写成 `@<<name>>`（否则会被当引用）；fence 要比正文里最长反引号串长（skill 正文里有四反引号的例子 → 用五个）。生成脚本 `experiments/2026-09-11-transliterate/self_typ.sh` 已经会做这两件事。
- **`--out` 是仓库根**：`lp tangle lp.typ --out . --check` 是干跑（不写任何东西），可以随时跑；`lp unaccounted ... --delete` 在这个仓库里等于对全仓库动刀——别在没看清单的时候跑。
- **`examples/demo/build/` 是生成物**（gitignore），里面有 `.lpignore`（唯一被跟踪的文件，靠 `.gitignore` 里的 `!` 规则）。
- **本会话里 pi-lens 偶尔报 `~/.config/pi-web/...` 的路径**（例如 `src/main.rs`、`out/a.py`）：那是 harness 把仓库相对路径按自己的 cwd 解析的**假象**，那些文件不存在；以仓库内路径为准。
