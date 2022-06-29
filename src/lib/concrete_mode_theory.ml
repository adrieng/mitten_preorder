type mode = String

type m = String

type cell =
  |  Atom of string
  | HComp of cell * cell
  |  VComp of cell * cell

let rec pp fmt = function
  | Atom s -> Format.fprintf fmt "%s" s
  | HComp (c1, c2) -> Format.fprintf fmt "hcomp(@[%a,@ %a@])" pp c1 pp c2
  | VComp (c1, c2) -> Format.fprintf fmt "vcomp(@[%a,@ %a@])" pp c1 pp c2
