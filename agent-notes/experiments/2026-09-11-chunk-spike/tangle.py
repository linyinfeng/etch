#!/usr/bin/env python3
"""Spike: tangle a Typst literate document into source files.

Chunk = fenced raw block with a trailing Typst label, either on the closing
fence line or on its own line:

    ```py
    code
    ``` <chunk-name>
    ...
    ``` <other>

Root chunks (labels that look like file names, e.g. <hello.py>) become output
files; other chunks are pulled in with noweb-style ``<<chunk-name>>`` lines.
Typst itself is the parser: we ask it for every labelled block via `typst eval`.
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

TYPST_STORE = "/nix/store/n1fhw9lc9zxmz1w11d1zykmsqwi5bxcd-typst-0.15.1/bin/typst"
TYPST = os.environ.get("TYPST") or shutil.which("typst") or TYPST_STORE
EVAL = (
    "query(raw.where(block: true))"
    '.filter(e => e.at("label", default: none) != none)'
    '.map(e => (label: str(e.at("label", default: none)), lang: e.lang, text: e.text))'
)
REF = re.compile(r"<<([^<>]+)>>")
ROOT = re.compile(r"^[A-Za-z0-9_./-]+\.[A-Za-z0-9]+$")


def query(doc):
    p = subprocess.run([TYPST, "eval", EVAL, "--in", doc], capture_output=True, text=True)
    if p.returncode:
        sys.exit(p.stderr.strip() or f"typst eval failed ({p.returncode})")
    return json.loads(p.stdout)


def label_lines(src):
    """Map label -> [lines of the closing fence carrying it], in document order."""
    out = {}
    for i, line in enumerate(src.splitlines(), 1):
        for m in re.finditer(r"^(?:`{3,}\s*)?<([A-Za-z0-9_./-]+)>\s*$", line):
            out.setdefault(m.group(1), []).append(i)
    return out


def first_code_line(src, fence_line):
    """Opening fence is the nearest '```' above the closing fence/label line."""
    lines = src.splitlines()
    for i in range(fence_line - 2, -1, -1):
        if lines[i].lstrip().startswith("```"):
            return i + 2  # 1-based line number of the first code line
    return None


def items(text, start):
    out = []
    for i, line in enumerate(text.split("\n")):
        m = REF.fullmatch(line.strip())
        if m:
            out.append(("ref", m.group(1), line[: len(line) - len(line.lstrip())], start + i))
        else:
            out.append(("lit", line, None, start + i))
    return out


def expand(name, chunks, typ, nth, indent="", stack=()):
    if name in stack:
        sys.exit(f"cycle: {' -> '.join([*stack, name])}")
    lines, mapping = [], []
    for blk, blk_typ in zip(chunks[name], typ[name]):
        for kind, a, local, typ_line in items(blk, blk_typ):
            if kind == "lit":
                mapping.append((len(lines) + 1, typ_line))
                lines.append(indent + a)
            else:
                sub, submap = expand(a, chunks, typ, nth, indent + local, (*stack, name))
                mapping += [(n + len(lines), t) for n, t in submap]
                lines += sub
    return lines, mapping


def main():
    doc = pathlib.Path(sys.argv[1])
    outdir = pathlib.Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else pathlib.Path("out")
    check = "--check" in sys.argv
    src = doc.read_text()
    labels = label_lines(src)

    chunks, meta, typ = {}, {}, {}
    for b in query(str(doc)):
        chunks.setdefault(b["label"], []).append(b["text"])
        meta.setdefault(b["label"], b)
    for name in chunks:
        typ[name] = [first_code_line(src, l) for l in labels[name]]
    roots = sorted(l for l in chunks if ROOT.fullmatch(l))
    if not roots:
        sys.exit("no root chunks (labels that look like file names)")

    stale, index = False, {}
    for root in roots:
        lines, mapping = expand(root, chunks, typ, None)
        dest = outdir / root
        new = "\n".join(lines) + "\n"
        if check:
            old = dest.read_text() if dest.exists() else None
            print(f"{'ok' if old == new else 'STALE':6} {dest}")
            stale |= old != new
        else:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(new)
            print(f"wrote  {dest}  ({len(lines)} lines, {meta[root]['lang']}, {pathlib.Path(root).suffix})")
        index[root] = {"typ": str(doc), "lang": meta[root]["lang"], "lines": mapping}
    if not check:
        (outdir / ".lpmap.json").write_text(json.dumps(index, indent=1) + "\n")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
