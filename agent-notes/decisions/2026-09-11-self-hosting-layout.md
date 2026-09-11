# D15 — 自举布局：冻结的种子、根目录即生成物、引用撞车怎么办（2026-09-11）

前置：`mvp-decisions.md` 的 D3（Rust 原型 → 冻结为 bootstrap → 自举）与 D4（生成物不入库 + `--check` 守漂移）。

## 决定

**1. 布局：crate 留在仓库根，`bootstrap/` 是冻结的种子。**

```
bootstrap/          # 冻结的原型 crate（tracked，永不重新生成）：Cargo.toml + src/ + tests/
self.typ            # 唯一真相：声明 Cargo.toml、src/*.rs、tests/*.rs
Cargo.toml src/ tests/   # 生成物（gitignore），`lp tangle self.typ --out .` 写它们
.lpignore           # 根目录保护清单：仓库里除生成物以外的东西
lit/ agent-notes/ examples/ experiments/ flake.nix README.md ...   # 手写资产，被 .lpignore 保护
```

- 生成物就在它现在的位置——不搬进 `crate/`、不动 `cargo test` 的路径。D3 里"为自举留位置"留的就是这个：`bootstrap/` 与根目录的 `src/` 共存。
- `--out .`（仓库根）意味着**所有权规则管整个仓库**，所以根 `.lpignore` 是自举的一部分：它列出所有手写资产（`.git/`、`target/`、`bootstrap/`、`lit/`、`agent-notes/`……）。新增一个手写顶层文件就要声明它，否则 `tangle` 报错——这是 D10 的本意，不是摩擦事故。

**2. 达成标准与永久不变量分开。**

- **达成（一次性）**：`bootstrap/target/debug/lp tangle self.typ --out . --check` 绿 = `self.typ` **逐字节**复现冻结前的手写源码。这一条只在"写 self.typ 那一刻"为真，之后 `self.typ` 一旦重构就不再等于 `bootstrap/`。
- **永久不变量（可重复）**：**自己构出来的二进制**跑 `lp tangle self.typ --out . --check` 必须绿（`tests/self.rs`）。它说的是"文档复现了我正在运行的那份源码"，与 bootstrap 无关，所以能一直测下去。
- `bootstrap/` 作为**种子**保留，不随 `self.typ` 更新：它是自举的工具链里唯一可信的起点（工具坏了、生成物丢了，它还在）。

**3. 引用撞车（`<<name>>` 单独一行）：不加转义语法，改我们的夹具。**

`rg '^\s*<<[^<>]+>>\s*$' src tests` 只命中 4 行——`tests/flow.rs` 与 `tests/lazy.rs` 里各有一个 Typst 夹具，夹具正文本身要写 `<<imports>>` / `<<body>>`。这些行进了 `self.typ` 的 raw block 就会被当成引用（未声明 → 悬空报错；万一撞上同名 chunk → 静默换成别的内容，更糟）。

- **决定**：在 Rust 源码里用 `concat!` 把这两行拼进去（结果字节完全一样），不发明语法。
- **理由**：撞车只出现在"目标语言文件里恰好有一个独占一行的 `<<name>>`"时，而 `<<name>>` 独占一行在真实代码里极罕见（夹具是因为它本身在写 Typst 才撞上）。为 4 行夹具加一门转义语法，是给所有人加一个必须学的概念。
- **升级路径（记录在案）**：若真有人在目标语言里需要这种行（或我们的散文越来越多样化），再加转义——最小形状是"**行首 `@` 前缀**"：`@<<name>>` 原样输出 `<<name>>`（`@` 去掉）。改动点只有 `tangle.rs` 的 `ref_target`、包里的 `ref-re`、以及 README。**现在不做。**

**4. raw block 的 fence 用 4 个反引号。**

源码里最长反引号串是 3（`tests/` 的 Typst 夹具）。用 4 个 fence 包住整个文件即可，不需要动态算长度；`#file(path, ```` ``````rust … ````)` 的 info string 仍是语言 tag。

**5. `lit/lp.typ` 不自我生成。**

它是"声明"这件事本身的实现，`self.typ` 要 import 它才能宣布 chunk——自举它需要先有它。它继续是手写的 tracked 资产，被 `.lpignore` 保护。

## 分阶段

- **Stage 1（本次）— 逐字节固定点**：`self.typ` 是 `bootstrap/` 源码的忠实转写（一个文件一个根 chunk，暂时不共享、不加散文）。验完 `--check` 后翻转：生成物从 git 移除，`self.typ` 成为唯一真相。
- **Stage 2（未做，需要时再说）— literate 化**：把重复片段抽成 `#chunk` 共享、加散文、按章节拆 `#include`。这时产物**不再**等于 `bootstrap/`；永久不变量（自复现 `--check`）仍然成立，达成标准那一栏变成历史记录。

## 落选方案

| 落选 | 为什么 |
| --- | --- |
| 生成到 `crate/`（或任何子目录），根只放工作区清单 | 所有权范围小、误删风险低，但把 `cargo test`、`examples/demo/run.sh`、AGENTS.md 里所有路径都改成 `--manifest-path`；为一个"更安全"的边界换掉每天用的路径。误删风险由"`lp` 从不自行删除 + 被删的都是 git 内容"兜住。 |
| 整个仓库只有 `self.typ`，`bootstrap/` 也由它生成 | 那就没有种子了：工具坏了以后没有任何可信起点。 |
| 把 `tests/` 排除在文档之外（留在 `.lpignore` 里手写） | 文档就只描述"一半的源码"，`--check` 也守不住另一半；自举的可用性测试正是要撞上夹具这种棘手内容。 |
| 给引用加转义语法（现在就做） | 见决定 3。 |
| 生成物入库（固定点靠 diff 看） | 与 D4 冲突：AI/人会去改生成物而不是文档。 |

## 影响的代价

- **首次 clone 不能直接编译**：要先跑 bootstrap（README 会写清三步）。这是 D4"生成物不入库"的必然结果，不是新增代价。
- **每次 `tangle` 走整棵仓库树**（`--out .`）：`ignore` 的 walker 会看 `target/`、`.git/`。实测数据在 `research/2026-09-11-lazy-tangle.md` 的同名议题下补充；若真成瓶颈，退路是把生成物收进一个子目录。
- `Cargo.lock` 与根 `.lpmap.json` 也落在 `--out` 范围内，需要在保护清单/生成物里各有归属。

## 验证（本 ADR 的结论怎么复核）

```sh
# 撞车清单（应为空，除夹具那 4 行的修复点）
rg -n '^\s*<<[^<>]+>>\s*$' src tests

# fence 长度（最长 3 → 用 4 个反引号）
rg -o '`+' -N tests/*.rs | awk '{print length($0)-length(substr($0,1,0))}' | sort -n | tail -1

# 达成标准
nix develop -c cargo build --manifest-path bootstrap/Cargo.toml
nix develop -c ./bootstrap/target/debug/lp tangle self.typ --out . --check

# 永久不变量
nix develop -c cargo test self
```
