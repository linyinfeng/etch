// Literate chunk styling for Typst. Label a fenced block to make it a named chunk.
#let ref-re = regex("^\\s*<<([^<>]+)>>\\s*$")
#let chunk-label(it) = it.at("label", default: none)

#let ref-link(name) = context {
  let target = query(raw.where(block: true)).find(x => {
    let l = chunk-label(x)
    l != none and str(l) == name
  })
  if target == none { text(fill: red)[⟪#name⟫] }
  else { text(fill: rgb("#0a6"))[#link(target.location())[⟪#name⟫]] }
}

#let lit(body) = {
  show raw.where(block: true): it => {
    let lbl = chunk-label(it)
    if lbl == none { it } else {
      block(breakable: true, width: 100%, inset: 8pt, radius: 3pt, fill: luma(238))[
        #text(size: 0.85em, weight: "bold", fill: luma(60))[⟪#str(lbl)⟫]
        #v(4pt)
        #for line in it.lines {
          let m = line.text.match(ref-re)
          if m == none { line.body } else {
            raw(line.text.slice(0, m.start)) + ref-link(m.captures.at(0))
          }
          linebreak()
        }
      ]
    }
  }
  body
}
