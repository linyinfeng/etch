#let ref-re = regex("^(\\s*)<<([^<>]+)>>\\s*$")

#let esc-re = regex("^(\\s*)@<<([^<>]+)>>\\s*$")

#let ref-indent(line) = {
  let m = line.match(ref-re)
  if m == none { "" } else { m.captures.at(0) }
}

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

#let lang-of(code) = code.at("lang", default: none)

#let chunk(name, code) = {
  [#metadata((
    lp: "chunk",
    name: name,
    lang: lang-of(code),
    text: code.text,
  ))<lp-decl>]
  tile(name, lang-of(code), code)
}

#let file(path, code) = {
  [#metadata((
    lp: "file",
    name: path,
    lang: lang-of(code),
    text: code.text,
  ))<lp-decl>]
  tile(path, lang-of(code), code)
}

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
