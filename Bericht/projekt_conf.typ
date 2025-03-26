#let conf(
  title: none,
  authors: (),
  abstract: [],
  doc) = {
  set text(
    size: 12pt
  )
  set page(
    paper: "a4",
    margin: (x: 2.5cm, y: 2.5cm),
    numbering: "1",
    header: [#set text(8pt) 
    #h(1fr) IO-Verhalten und -Effizienz im Klima- und Wettermodell ICON],
  )
  set par(
    justify: true,
    leading: 0.7em,
  )
  set heading(
    numbering: "1.",
  )

  set align(center)
  text(20pt, title)

  let count = authors.len()
  let ncols = calc.min(count, 3)
  grid(
    columns: (1fr,) * ncols,
    row-gutter: 24pt,
    ..authors.map(author => [
      #author.name \
      #author.affiliation \
      #link("mailto:" + author.email)
    ]),
  )

  par(justify: false)[
    *Abstract* \
    #abstract
  ]

  set align(left)
  doc
}

