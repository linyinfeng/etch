# 接手说明（handoff）— 2026-09-11，截至 `0be430a`

> 这是**快照**，会过期。行动前先 `git log --oneline -5`、读 `agent-notes/README.md`（索引 + 当前状态），细节都指向 `research/` 与 `decisions/`。

## 0. 30 秒

- **是什么**：`lp` —— 基于 Typst 的 literate programming 工具。同一个 `.typ` 文档既是可排版的文档（weave = `typst compile`），也是多种目标语言源码的唯一真相（tangle = `lp tangle`）。与目标语言正交：工具里没有任何目标语言知识。
- **仓库**：`~/Projects/literate`（分支 `main`，`0be430a`，工作树干净）。devshell 带 `typst 0.15.1` + `cargo 1.97`：`nix develop -c <cmd>`。
- **三件事先跑一遍**：`nix develop -c cargo test`（47 个测试，**需要 typst**）、`nix develop -c examples/demo/run.sh`（端到端）、`nix develop -c cargo run -- --help`。

## 1. 它现在是什么（行为契约）

| 问题 | 谁回答 | 机制 |
| --- | --- | --- |
| 有哪些 chunk、什么顺序、文本、语言 | **Typst 求值** | 文档 import `lit/lp.typ` 用 `#chunk(name, ```…```)` / `#file(path, ```…```)` **声明**；工具 `typst eval 'query(<lp-decl>)'` 读回来。`#for`/`#if`/函数/`#include` 生成的 chunk 一视同仁 |
| `<<name>>` 展开、缩进、悬空/环/空 chunk 报错 | `lp`（`tangle.rs`） | 纯文本替换 + 每行缩进；作用在**求值后**的文本上 |
| 每行输出从哪来 | `lp`（`map.rs`，schema v5） | **chunk 区间**：`runs = [{chunk, first, last}]`，每目录一份 `.lpmap.json`。**没有 `.typ` 行号**（见 §2） |
| 输出目录里的东西归谁 | `lp`（`status.rs`） | 三类：**produced**（`#file` 声明写的）/ **declared**（`.lpignore`，规则即 gitignore、**匹配=保护**）/ **unaccounted**（都不是 → `tangle` **报错**；只有 `lp unaccounted --delete` 才删） |
| weave | `typst compile` | 包同时负责渲染（带标题的块 + 引用标记），文档不需要样式 show rule |

`lp watch`：`notify` + 去抖；**只写变化的字节**（mtime 不动）；**文档不能求值就跳过本轮并保留上一份好产物**；`--check-cmd` 只在真改写后跑并把诊断回译成 chunk。契约见 `decisions/2026-09-11-watch-contract.md`。

## 2. 铁规矩（先读这一节再动手）

1. **优雅是准入条件**：**活不能优雅地做 → 不做**。任何功能若只能靠启发式搜索、字符串匹配源码、或与 Typst 版本耦合的重复解析实现，就**不做**，而不是先脏着做出来（`AGENTS.md` 里）。
2. **不解析 Typst**：工具对 Typst 的全部理解 = 跑一次 `typst eval` 读声明流。不要引入 `typst-syntax` 之类去"理解文档"。
3. **不做行号映射**：不是待办，是**已决定不做**（Typst 脚本层拿不到源位置；要行号就得破规矩 1/2）。见 `decisions/2026-09-11-no-positions.md` 与 `research/2026-09-11-source-positions.md`。
4. **正交性**：算法里不得出现目标语言知识；语言差异只能是数据表。
5. **生成物不入库**：`examples/demo/build/` 之类一律 gitignore；CI 用 `lp tangle --check` 守漂移。

## 3. 决策索引（一句话版）

| ADR | 决定 |
| --- | --- |
| `mvp-decisions.md` | 场景=多文件工程；形态=纯 `.typ`；实现=Rust→自举；生成物不入库；错误定位=D1（已被 D14 取代） |
| `engine-and-deps.md` | D6 引擎（后来由 D13 取代）；D7 用成熟库，不手写已被解决的问题 |
| `chunk-labels.md` | ~~label 当 chunk 名~~ → 被 D13 取代（保留字符集限制的历史记录） |
| `output-ownership.md` | D10 删除只由 `.lpignore` 声明授权；map 不再是账本；`--check` 是干跑 |
| `watch-contract.md` | D9 只写变化字节 / 不 tangle 半写文档 / 事件合并 / check 融合 |
| `map-scope.md` | D11 每目录一份 map；v3 起 per-line 源文件 |
| `typst-is-the-authority.md` | D12 chunk 的权威是 Typst 求值；**含 show rule 埋点为何脆的实测** |
| `declared-chunks.md` | D13 **声明式 chunk**：`#chunk`/`#file`，声明自带 name/lang/text |
| `no-positions.md` | D14 **删掉行号映射**，出处降到 chunk 级；`locate.rs`/`source.rs` 删除 |

## 4. 不许回头做的事（都踩过，附证据）

| 别做 | 为什么 |
| --- | --- |
| 用 Rust 静态分析 Typst（`typst-syntax`） | 图灵完备下**构造上就是错的**：循环里 `raw(...)` 造出的 chunk，其正文在源文件里一行都没有（实测，见 D13） |
| 用 `#show raw` 埋点收集 chunk | 样式化规则一旦**消费元素**就失效——我们自己的包就是这么渲染的，demo 上 chunk 曾全丢（实测，见 D12） |
| 在源码里搜索声明 token 定位行号 | 实测在**自己的 demo** 上指到了散文（第 61 行 vs 声明的第 64 行），见 `research/2026-09-11-source-positions.md` |
| 自己实现 `.lpignore` 的匹配/优先级 | `ignore` crate 的 walker 就是干这个的（`status.rs` 已交回给它） |
| 往生成物注入行指令 / `#line` | 语言无关性 + `--check` 要逐字一致；已被 D5 否掉 |

## 5. 当前状态与已知脏点

- **测试 47 个**（`6 单元 + 19 flow + 5 lazy + 7 metadata + 10 owned`），clippy/fmt 干净，`examples/demo/run.sh` 全绿（tangle → cargo run → weave → `--check` → map → explain 回译 → 复原）。
- 规模：`src/` 约 1.5k 行（`tangle` 449 / `status` 367 / `main` 279 / `map` 211 / `watch` 168 / `metadata` 109 / `explain` 54 / `diag` 53）+ 包 `lit/lp.typ` 76 行。
- 上一轮审计后**剩余**的脏点（按程度）：
  1. `metadata.rs` 的 `QUERY` 字符串与包之间是隐式契约（字段名两处各写一遍；serde 会兜住缺字段，未知 kind 已在边界报错）——低风险，值得一句注释/一个断言；
  2. `status.rs` 的 `compress` 用字符串拼路径（`format!("{prefix}{child}")`）——展示层，建议留；
  3. `main.rs` 的 `list` 重复 `plan()` 的一小段（自建 ChunkSet/referenced）——3 行，建议留；
  4. `examples/demo/run.sh` 用 `sed -i` 改动生成物来演示报错回译——演示步骤，已注明。

## 6. 下一步候选（带代价）

| | 内容 | 代价 |
| --- | --- | --- |
| A | `lp explain --format cargo`（`cargo_metadata` 解 JSON）+ `ci.sh`（compile + test + `--check`） | 小，M2 尾巴 |
| B | 分节归属：用 `location()` 按 `(page, y)` 合并 heading 流与声明流（已验证可行） | 中；但注意 D12 的教训——别再依赖 show rule |
| C | "章节即文件"：heading 带 `<src/main.rs>`，该节内声明的 chunk 都归这个文件 | 语义变化，需新 ADR |
| D | 自举 M3：原型冻结 `bootstrap/`，工具自身源码写成 `self.typ` + 固定点测试（tangle 产物与手写源码逐字节相同） | 大，项目目标是自举 |
| E | `lit/lp.typ` 发布成 `@preview` 包（目前只能 `#import "相对路径"`） | 小-中，需要包名与版本策略 |

## 7. 环境陷阱

- **`typst` 必须在 PATH**（或 `LP_TYPST`）：tangle 靠它读声明，`cargo test` 也需要 → 一律 `nix develop -c ...`。
- **flake 只看 git 已跟踪的文件**：新建/改 `flake.nix` 后要先 `git add`，否则 `nix develop` 报 `not tracked by Git`。
- **`.lpignore` 语义与 `.gitignore` 反向**：匹配 = **保护**（"要保留什么"的清单），不是"忽略"。控制文件只有 `.lpignore` 与 `.lpmap.json`，**没有 git 特例**，点文件是普通内容。
- **`examples/demo/build/` 是生成物**（gitignore），里面有 `.lpignore`（唯一被跟踪的文件，靠 `.gitignore` 里的 `!` 规则）。
- **本会话里 pi-lens 偶尔报 `~/.config/pi-web/...` 的路径**（例如 `src/main.rs`、`out/a.py`）：那是 harness 把仓库相对路径按自己的 cwd 解析的**假象**，那些文件不存在；以仓库内路径为准。
