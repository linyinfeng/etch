#import "../../package/lib.typ": chunk, file

= Reading a diagnostic back to the declaration

The compiler knows nothing about this document. It knows `src/main.rs`, and it will report
`src/main.rs:6:38: cannot find function 'ad' in module 'math'` for a line that exists here
only as part of a chunk. The question that follows is the one this chapter answers: which
declaration do I edit?

The tempting answer is to make the compiler say it — inject `#line` directives, or
whatever the target language uses, so the toolchain's own positions point into this
document. That was rejected, and not on taste. The generated file has to stay
byte-for-byte what a person would have written, or `--check` can no longer compare it and
every language needs a special case for a directive it may not even have; and the
positions we could inject would be `.typ` line numbers, which do not exist, because Typst
does not expose them (ADR D14, with the measurements behind it).

So the mapping is built on the side, while tangling: every generated line is recorded
together with the declaration it came from. What is left for `etch explain` is a filter with
no opinion about any language at all — it echoes what it reads, and for each line shaped
like `file:line:col:` it adds one note about where that line came from.

== The shape of the filter

Every line of this file is a name; the details come in the sections after it.

#file("src/explain.rs", ````rust
<<explain: the imports>>

pub fn run(out: &Path, input: &str) -> Result<usize, EtchError> {
    <<the diagnostic pattern>>

    let maps = EtchMap::read_all(out)?;
    let mut mapped = 0;

    for line in input.lines() {
        println!("{line}");

        <<one line, annotated>>
    }

    Ok(mapped)
}
````)

The count it returns is not decoration: the caller uses it to warn that no diagnostic line
matched anything, which is the difference between "the build is clean" and "the filter
never recognised a single line".

== Why the file explains nothing by itself

Someone who opens the generated `src/explain.rs` gets the code and nothing else: no note at the top, no line
over the pattern. That is the rule this document keeps everywhere — an explanation belongs in the prose that
introduces the fragment — and it is a rule with a cost in exactly this place, because the tree travels. It gets
built, shipped and read by people who never open this book, and those readers would rather have the note.

What pays for the rule is that a second copy of the argument would drift while a pointer would need
maintaining, and the file has nowhere to put either that the document would notice. So the code has one home,
the reasoning has one home, and `etch map` is what connects the two for a reader who arrives from the tree.

== What the filter needs

The regex engine, the path type, this crate's error type, and the map reader with its two
helpers. `resolve_all` is the interesting one: a diagnostic names a file, and the set of
directory maps that could explain it is searched rather than guessed (`map.rs`, next).

#chunk("explain: the imports", ````rust
use std::path::Path;

use regex::Regex;

use crate::diag::EtchError;
use crate::map::{EtchMap, join, resolve_all};
````)

== One pattern, and it is not language knowledge

The pattern recognises a shape that compilers and linters have printed for decades:
`path:line:column:` followed by a message. That is deliberately the whole of this
program's idea of a diagnostic. A toolchain that prints something else — a Python
traceback, or cargo's JSON — wants another pattern beside this one, not another
algorithm (ADR D5).

#chunk("the diagnostic pattern", ````rust
let pattern = Regex::new(r"^(?P<file>[^\s:]+\.\w+):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
    .map_err(|err| EtchError::plain(format!("internal: bad diagnostic pattern: {err}")))?;
````)

== Give up quietly, or say where the line came from

Three chances to give up quietly: the line is not a diagnostic, no map knows that file, or
the map does not cover that line. When the line *can* be placed, note which stream carries
which half: the input is echoed unchanged on stdout, so the filter can sit in the middle of a pipeline,
and the note follows the line it annotates on that same stream — the stream is the filter's product, not a
report about it, and the note is marked with a character no compiler prints.

#chunk("one line, annotated", ````rust
let Some(caps) = pattern.captures(line) else {
    continue;
};
let (file, out_line) = (&caps["file"], caps["line"].parse::<usize>().unwrap_or(0));
let Ok((dir, name, entry)) = resolve_all(&maps, file) else {
    continue;
};
let Some((run, offset)) = entry.locate(out_line) else {
    continue;
};
let rel = join(dir, name);
println!(
    "  ↳ chunk ⟪{}⟫, line {offset} of it  ({rel}:{out_line})",
    run.chunk
);
mapped += 1;
````)
