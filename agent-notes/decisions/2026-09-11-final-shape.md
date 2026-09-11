# D19 — 仓库的最终形态（2026-09-11，目标）

用户给出的目标（原话）：

> AGENTS.md + README.md - 一句话，指向 typ 文件
> lp.typ - lp 本身，完全自解释，自包含
> seed - 一个能 bootstrap lp.typ 的老的 lp
> agent-notes - 一些不适合进入 lp 本体的经验
> 没了

也就是说：**git 里最终只有这五样**，其余一切都是生成物（`Cargo.toml`、`src/`、`tests/`、`lit/lp.typ`、skill、`examples/`……）。本 ADR 记目标与迁移路线；**尚未执行**，等下面几个问题拍板。

## 现状 → 目标

| 现在（tracked） | 最终 | 怎么变 |
| --- | --- | --- |
| `README.md` / `AGENTS.md`（长文） | 各自**一句话** + 指向 `lp.typ` | 规则与结构搬进 `lp.typ`（skill 那一节 + 文档自身的铺陈）；AGENTS 的一句是"读 lp.typ" |
| `self.typ`（3778 行） | `lp.typ` | 改名；并把包也收进来（见下） |
| `lit/lp.typ`（手写包） | 生成物 | `lp.typ` 里 `#chunk("lp-package", …)` + `#file("lit/lp.typ", …)`；**求值顺序**：seed 先产出 `lit/lp.typ`，之后任何人可 `typst compile lp.typ` / `lp tangle lp.typ` |
| `bootstrap/` | `seed/` | 改名 + **刷新到能读 `@` 转义**（现行种子读不了 D17 的语法，见下） |
| `examples/demo/`（`literate.typ` + `run.sh` + 数据） | `lp.typ` 里的根 chunk（生成物） | 端到端仍然被测试覆盖（demo 的 tangle→build→weave→explain 往返是一条回归） |
| `experiments/`（spike、probe、转写脚本） | 删除 | 结论已经在 `agent-notes/research/`；代码留在 git 历史里 |
| `flake.nix` / `.gitignore` / `.lpignore` / `Cargo.lock` / `.pi/` | **待定** | 它们是环境与控制文件，不是"要读的东西"；但它们也不是内容 |
| `agent-notes/` | 保留 | "不适合进入 lp 本体的经验" |

## 目标形态下的不变量

1. **`lp.typ` 是唯一真相**，且自足：它声明 crate、包、skill、示例；`typst compile lp.typ` 直接把工具本身渲染成文档。
2. **种子只负责一件事**：在什么都还没有的仓库里产出第一代 `src/` 与 `lit/lp.typ`，之后由产物接管。
3. **仓库里没有第二份代码/散文副本**：README/AGENTS 只有指针，规则、设计、用法都在 `lp.typ` 的铺陈里。

## 卡住的几个决定

1. **脚手架算不算"没了"**：`flake.nix` 是 typst/cargo 的来源，`.gitignore` 排除生成物，`.lpignore` 是所有权清单（D10 的一部分）。删掉它们会同时破坏所有 `nix develop -c …` 与 `--check`。建议：**留在 git 里，但不当作"内容"**（不计入那五样，也不在文档里叙述）。
2. **`examples/`**：折进 `lp.typ`（生成物、回归保留）还是删掉（回归只剩 `tests/` 与 skill 里那个已验证的例子的抄本）？
3. **`experiments/`**：直接删（结论已入库）还是搬进 `agent-notes/`？
4. **种子的刷新策略**：语法长过种子的那一刻（已经发生过一次：D17 的 `@`），只能二选一——(a) 把种子刷新成**当前一代**（种子 = 上一代产物，永远是"老的 lp"，但语法上够用）；(b) 永不刷新，等于把文档可用的语法冻死在种子那一代。建议 (a)，并配一个"种子能不能 bootstrap `lp.typ`"的检查。
5. **包也进文档**（`lit/lp.typ` 变生成物）会带来一个求值顺序的约束：干净仓库里必须先跑种子产出 `lit/lp.typ`，才能求值 `lp.typ`。接受吗？（不接受的话，`lit/lp.typ` 就得留着当手写资产，目标里的"五样"就要加一项。）
