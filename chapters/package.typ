#import "@local/lp:0.1.0": chunk, file

= The package: what a declaration is

This document is written with four functions — `chunk`, `file`, `tangle-options` and `show-rule` — and none
of them is built into the tool. They are declared in `typst/lp.typ`, which this document produces: the
syntax and the tool that reads it share one source, so there is no second opinion about what a declaration
looks like.

`chunk` and `file` do two things each: they attach a metadata record — the name, the language from the
fence, the text — and then render the code as a titled block. That is the whole difference between a
fragment and a root: the same body, one word, and a record that says which of the two it is. `show-rule`
marks references when the document is woven, and it is the only one of the four that is about the page.

The declarations deliberately do not depend on that show rule. A show rule that consumes an element can
hide it from a query, and that is not a hypothesis: a styling rule once made every chunk in this project
vanish from the pass that collects them (ADR D12). So the metadata is attached where the declaration is
written, and rendering is free to be as decorative as it likes afterwards.

#file("typst/typst.toml", ````toml
<<package: the manifest>>
````)

#file("typst/lp.typ", ````typst
<<package: what a reference looks like>>

<<package: the escape>>

<<package: the indentation a reference contributes>>

<<package: the show rule>>

<<package: how a chunk is rendered>>

<<package: a fence without a language>>

<<package: a fragment>>

<<package: a root>>

<<package: options>>
````)

A file in this document is a skeleton of references plus the fragments that fill it, and this is the
skeleton for the package: the file's own table of contents, shown before the pieces are argued for. Every
chapter in this part is arranged that way — the file it produces, then the sections that explain what is
in it.

== The two patterns

The reference is a whole line: indentation, `<<`, a name without angle brackets, `>>`, and nothing else.
The indentation is captured rather than ignored, because it is part of what a reference *means* — it is
what indents the expansion when tangling, so the woven page has to show it too, or the page disagrees with
the file it claims to describe.

The second pattern is the escape, and it exists because this document quotes itself: a chapter showing what
a reference looks like has to write a line that looks exactly like one.

#chunk("package: what a reference looks like", ````typst
#let ref-re = regex("^(\\s*)<<([^<>]+)>>\\s*$")
````)

#chunk("package: the escape", ````typst
#let esc-re = regex("^(\\s*)@<<([^<>]+)>>\\s*$")
````)

#chunk("package: the indentation a reference contributes", ````typst
#let ref-indent(line) = {
  let m = line.match(ref-re)
  if m == none { "" } else { m.captures.at(0) }
}
````)

== The show rule, and the one thing it must not do

Marking references is cosmetics. What the rule must not do is *consume* anything: it walks the lines of a
raw block and rebuilds them, so the element it was handed stays where it was for anyone who queries it
later. Everything a reader sees as a marked reference is a second rendering of a line that is still the
line that was written.

#chunk("package: the show rule", ````typst
#let show-rule(body) = {
  show raw.where(block: true): it => {
    let out = none
    for line in it.lines {
      let escaped = line.text.match(esc-re)
      let m = line.text.match(ref-re)
      let piece = if escaped != none {
        raw(escaped.captures.at(0) + "<<" + escaped.captures.at(1) + ">>")
      } else if m == none {
        line.body
      } else {
        (
          raw(ref-indent(line.text))
            + text(fill: rgb("#0a6"))[⟪#m.captures.at(1)⟫]
        )
      }
      out = if out == none { piece + linebreak() } else {
        out + piece + linebreak()
      }
    }
    out
  }
  body
}
````)

#chunk("package: how a chunk is rendered", ````typst
#let tile(name, lang, code) = block(
  breakable: true,
  width: 100%,
  inset: 8pt,
  radius: 3pt,
  fill: luma(238),
)[
  #text(size: 0.85em, weight: "bold", fill: luma(60))[⟪#name⟫]
  #h(0.6em)
  #text(size: 0.7em, fill: luma(120))[#if lang != none { lang }]
  #v(4pt)
  #code
]
````)

== A tag that may be missing

A fence without an info string has no `lang` field at all in Typst, which is why the field is read with a
default. The tag is data rather than a promise (D18), so a missing one means "not declared" and the tool
records nothing.

#chunk("package: a fence without a language", ````typst
#let lang-of(code) = code.at("lang", default: none)
````)

== The manifest

A local package is a directory with a manifest and an entry point, so the manifest is part of what this
document produces: name, version, and the file Typst should read. Its name and version are the other half
of the import at the top of this file — `@local/lp:0.1.0` — and the only thing tying the two together is
that a wrong pair fails loudly, with Typst saying it cannot find the package.

#chunk("package: the manifest", ````toml
[package]
name = "lp"
version = "0.1.0"
entrypoint = "lib.typ"
````)

== The two declarations

Two nearly identical functions, and the whole difference is the record's first field. They are written out
rather than generated from a parameter because the metadata's shape is the interface between the document
and the tool: it should be readable in one place, not assembled from an argument.

#chunk("package: a fragment", ````typst
#let chunk(name, code) = {
  [#metadata((
    lp: "chunk",
    name: name,
    lang: lang-of(code),
    text: code.text,
  ))<lp-decl>]
  tile(name, lang-of(code), code)
}
````)

#chunk("package: a root", ````typst
#let file(path, code) = {
  [#metadata((
    lp: "file",
    name: path,
    lang: lang-of(code),
    text: code.text,
  ))<lp-decl>]
  tile(path, lang-of(code), code)
}
````)

== Settings, and why they are a dict

Not everything a document says is a chunk. Some of it is about the tangling itself — where the book is
carried, which of its files travel with the tree — and it belongs in the document rather than on the
command line: the output is the book's, not the invocation's, and a tree whose contents depend on how
someone called the tool is a tree nobody can check.

So there is one function for settings, and it takes a dict. A dict because the set of settings will
change: adding one should add a key, not another name to the syntax. Unknown keys are refused where they
are written, which is the only place the mistake is still fresh.

#chunk("package: options", ````typst
#let tangle-options(options) = {
  let known = ("book-directory", "book-files")
  for key in options.keys() {
    if not known.contains(key) {
      panic(
        "unknown tangle option: " + key + " (known: " + known.join(", ") + ")",
      )
    }
  }
  [#metadata((lp: "options", options: options))<lp-decl>]
}
````)
