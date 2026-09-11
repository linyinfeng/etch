# Probe: `typst-syntax` 能否给出 span 与正确的 chunk 文本（2026-09-11）

目的：回答 D6 的关键问题——**不调 typst CLI、直接链官方 parser crate**，能不能拿到 (a) chunk 的 lang/label/正文，(b) 精确字节区间与行号，(c) 与 `typst eval` 完全一致的正文。**丢弃型验证代码。**

## 怎么跑

```sh
nix develop -c cargo run --manifest-path experiments/2026-09-11-typst-syntax-probe/Cargo.toml -- probe.typ
# oracle 对照：
nix develop -c typst eval 'query(raw.where(block: true)).filter(e => e.at("label", default: none) != none).map(e => (label: str(e.at("label", default: none)), lang: e.lang, text: e.text))' --in probe.typ
```

## fixture 覆盖

`probe.typ` 里放了：列表内缩进的 chunk、label 在 closing fence 同行、label 独占一行、同名 label 两块、未标 label 的块。

## 结论（实测，两条路逐字节一致）

| 问题 | 结果 |
| --- | --- |
| 拿到 span？ | ✅ `Source::detached(text)` + `LinkedNode::range()` 给出字节区间；`src.lines().byte_to_line()` 给行号 |
| 找到 chunk？ | ✅ 递归遍历即可。**注意：列表/图表里的 chunk 是嵌套节点，只看顶层 children 会漏** |
| label 怎么关联？ | ✅ raw 的 `next_sibling()` 是 `SyntaxKind::Label` 节点；同行与独行两种写法都识别 |
| 多块同名？ | ✅ 两块都返回（Typst 不报错） |
| 正文是否等于渲染结果？ | ✅ `raw.lines()` 与 `typst eval` 的 `text` 逐字节相同；**Typst 的公共缩进裁剪由 parser 的 `RawTrimmed` 节点完成，不需要我们复刻** |
| 需要 typst 二进制吗？ | ❌ 不需要（只有 weave 和 oracle 测试需要） |

这条结论直接推翻了 Python spike 里"用 label 唯一性反查行号 + 向上找 fence"的做法：那是拿不到 span 时的将就，遇到嵌套块就错。
