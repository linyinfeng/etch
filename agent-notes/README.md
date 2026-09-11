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

- `research/2026-09-11-prior-art.md` — 现有 literate programming 工具盘点（noweb/littst/Entangled/Ravel/typst-unlit/Calepin/org-babel/…），Typst 生态现状，以及 AI 时代的四篇相关工作。含"我们的差异化在哪"。
- `research/2026-09-11-typst-engine-facts.md` — **只用 typst 自己当解析器**这套架构的全部实测事实：`typst eval` / `query`、label 当 chunk 名、raw info string 的坑、plugin 不能写文件、show rule 里的 label/link 语义。所有结论都附可复现命令。
- `research/2026-09-11-design-space.md` — 三种候选架构对比、推荐方案、需要用户拍板的决策清单、正交性的边界（哪些目标语言会破坏"语言无关"）、下一步 backlog。
- `../experiments/2026-09-11-chunk-spike/` — 可运行的最小验证：纯 `.typ` 同时 weave 成 PDF、tangle 成可运行的 `hello.py`，带 `--check` 漂移检测和行号映射。

## 当前状态（截至 2026-09-11）

- 仓库刚起步，只有调研 + spike，**没有产品代码**。
- 核心假设已用 spike 证实：`.typ` 里的 fenced raw block + Typst label 就是 chunk，`typst eval` 就是 tangle 的解析器，weave 就是 `typst compile`。不需要自写 Typst 解析器，也不需要给文档加预处理语法。
- 尚未决定：实现语言、chunk 引用语法、生成物是否入库、错误定位方案。见 design-space 的决策清单。
- 已知最大缺口（同时也是本项目的主要差异化）：**tangled 文件里的报错如何映射回 `.typ` 行号**。现有 Typst 方案（littst、typst-unlit）都明确不解决这个。
