open Sexplib
module C = Concrete_syntax
module SMap = Map.Make(String)

exception Modality_error of string
let error_m str = raise (Modality_error str)

type mode =
  | S

let equal_mode S S = true

type m = Warp.Periodic.t

let idm = Warp.Periodic.one

let compm (mu, nu) = Warp.Periodic.on mu nu

let dom_mod _ _ = S
let cod_mod _ _ = S

let eq_mode S S = true

let leq p q = Warp.Periodic.(q <= p)

let eq_mod = Warp.Periodic.equal

let mode_to_sexp S = Sexp.Atom "s"
let mode_pp m = mode_to_sexp m |> Sexp.to_string_hum

let mod_to_sexp mu =
  Sexp.Atom (Warp.Utils.print_to_string Warp.Periodic.print mu)
let mod_pp mu = mod_to_sexp mu |> Sexp.to_string_hum

let bind_mode = function
  | "S" | "s" -> S
  | str -> error_m (str ^ " is not a mode of the time warp theory")

let bind_m xs =
  try List.map Warp.Periodic_parse.of_string xs
      |> List.fold_left Warp.Periodic.on Warp.Periodic.one
  with Invalid_argument reason ->
    error_m @@ "syntax error (" ^ reason ^ ")"
