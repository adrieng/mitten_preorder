open Sexplib
open Mode_theory

type envhead =
  | Val of t
  | M of m
and env = envhead list
and clos = Clos of {term : Syntax.t; env : env}
and clos2 = Clos2 of {term : Syntax.t; env : env}
and clos3 = Clos3 of {term : Syntax.t; env : env}
and t =
  | Lam of clos
  | Neutral of {tp : t; term : ne}
  | Nat
  | Zero
  | Suc of t
  | Pi of m * t * clos
  | Sig of t * clos
  | Pair of t * t
  | Refl of t
  | Id of t * t * t
  | Uni of Syntax.uni_level
  | Tymod of m * t
  | Mod of m * t
and ne =
  | Var of int (* DeBruijn levels for variables *)
  | Ap of m * ne * nf
  | Fst of ne
  | Snd of ne
  | NRec of clos * t * clos2 * ne
  | Letmod of m * m * clos * clos * t * ne
  | J of clos3 * clos * t * t * t * ne
  | Axiom of string * t
and nf =
  | Normal of {tp : t; term : t}

let mk_var tp lev = Neutral {tp; term = Var lev}

(* env_val is giving the nth entry of the environment list, ONLY counting values. env_cell then gives the corresponding
   cell as it is required for the nbe algorithm *)

let rec env_val env i =
  match env with
  | [] -> failwith "env_val should not reach the empty list"
  | head :: lst ->
    match head with
    | Val v -> if Int.equal i 0 then v
      else if i > 0 then env_val lst (i - 1)
      else failwith "env_cell does not accept negativ Input"
    | M _ -> env_val lst i


let rec int_of_syn = function
  | Zero -> Some 0
  | Suc t ->
    begin
      match int_of_syn t with
      | Some i -> Some (i + 1)
      | None -> None
    end
  | _ -> None

let rec go_to_sexp size env = function
  | Val ty ->
    let if_value = function
      | Nat -> Sexp.Atom "Nat"
      | Zero -> Sexp.Atom "zero"
      | Suc t ->
        begin
          match int_of_syn t with
          | Some i -> Sexp.Atom (string_of_int (i + 1))
          | None -> Sexp.List [Sexp.Atom "suc"; go_to_sexp size env (Val t)]
        end
      | Pi (mu, src, dest) ->
        Sexp.List
          [Sexp.Atom "Pi";
           mod_to_sexp mu;
           go_to_sexp size env (Val src);
           go_to_sexp_clos size env dest]
      | Lam t ->
        Sexp.List [Sexp.Atom "lam"; go_to_sexp_clos size env t]
      | Sig (fst, snd) ->
        Sexp.List
          [Sexp.Atom "Sig";
           go_to_sexp size env (Val fst);
           go_to_sexp_clos size env snd]
      | Pair (t1, t2) ->
        Sexp.List [Sexp.Atom "pair"; go_to_sexp size env (Val t1); go_to_sexp size env (Val t2)]
      | Tymod (mu, tp) ->
        Sexp.List
          [Sexp.Atom "<";
           mod_to_sexp mu;
           Sexp.Atom "|";
           go_to_sexp size env (Val tp);
           Sexp.Atom ">"]
      | Mod (mu, tm) ->
        Sexp.List [Sexp.Atom "mod"; mod_to_sexp mu; go_to_sexp size env (Val tm)]
      | Id (ty, le, ri) -> Sexp.List [Sexp.Atom "Id"; go_to_sexp size env (Val ty); go_to_sexp size env (Val le); go_to_sexp size env (Val ri)]
      | Refl tm -> Sexp.List [Sexp.Atom "Refl"; go_to_sexp size env (Val tm)]
      | Uni i -> Sexp.List [Sexp.Atom "U"; Sexp.Atom (string_of_int i)]
      | Neutral {tp; term} -> Sexp.List [Sexp.Atom "up"; go_to_sexp size env (Val tp); go_to_sexp_ne size env term] in
    if_value ty
  | M mu -> mod_to_sexp mu
and go_to_sexp_clos size env = function
  | Clos body ->
    let var = Sexp.Atom ("x" ^ string_of_int size) in
    let new_env = var :: List.map (go_to_sexp size env) body.env |> List.rev in
    Sexp.List [var; Sexp.Atom "->"; Syntax.to_sexp new_env body.term]

and go_to_sexp_ne size env = function
  | Var i ->
    if i >= size
    then Sexp.Atom ("x" ^ string_of_int i)
    else List.nth env i
  | Ap (_, f, a) ->
    Sexp.List [Sexp.Atom "ap"; go_to_sexp_ne size env f; go_to_sexp_nf size env a]
  | Fst p -> Sexp.List [Sexp.Atom "fst"; go_to_sexp_ne size env p]
  | Snd p -> Sexp.List [Sexp.Atom "snd"; go_to_sexp_ne size env p]
  | NRec (motive, zero, Clos2 suc, n) ->
    let suc_var1 = Sexp.Atom ("x" ^ string_of_int (size + 1)) in
    let suc_var2 = Sexp.Atom ("x" ^ string_of_int (size + 2)) in
    let senv = suc_var2 :: suc_var1 :: List.map (go_to_sexp size env) suc.env |> List.rev in
    Sexp.List
      [Sexp.Atom "nrec";
       go_to_sexp_clos size env motive;
       go_to_sexp size env (Val zero);
       Sexp.List [suc_var1; suc_var2; Syntax.to_sexp senv suc.term];
       go_to_sexp_ne size env n]
  | Letmod (mu, nu, mot, deptm, _, ne) ->
    Sexp.List
      [Sexp.Atom "let";
       mod_to_sexp mu;
       Sexp.Atom "mod";
       mod_to_sexp nu;
       Sexp.Atom "<--";
       go_to_sexp_ne size env ne;
       go_to_sexp_clos size env deptm;
       go_to_sexp_clos size env mot
      ]
  | J (Clos3 mot, refltm, ty, le, ri, eq) ->
    let rivar = Sexp.Atom ("x" ^ string_of_int (size + 1)) in
    let levar = Sexp.Atom ("x" ^ string_of_int (size + 2)) in
    let prfvar = Sexp.Atom ("x" ^ string_of_int (size + 3)) in
    let mot_senv = prfvar :: levar :: rivar :: List.map (go_to_sexp size env) mot.env |> List.rev in
    Sexp.List
      [Sexp.Atom "J";
       Sexp.List [rivar; levar; prfvar; Syntax.to_sexp mot_senv mot.term];
       go_to_sexp_clos size env refltm;
       go_to_sexp size env (Val ty);
       go_to_sexp size env (Val le);
       go_to_sexp size env (Val ri);
       go_to_sexp_ne size env eq;
      ]
  | Axiom (str, _) -> Sexp.Atom str

and go_to_sexp_nf size env (Normal {tp; term}) =
  Sexp.List
    [Sexp.Atom "down";
     go_to_sexp size env (Val tp);
     go_to_sexp size env (Val term)]

let to_sexp = go_to_sexp 0 []
let to_sexp_nf = go_to_sexp_nf 0 []
let to_sexp_ne = go_to_sexp_ne 0 []

let pp t = to_sexp (Val t) |> Sexp.to_string_hum
let pp_nf t = to_sexp_nf t |> Sexp.to_string_hum
let pp_ne t = to_sexp_ne t |> Sexp.to_string_hum
let pp_clos size env clos = go_to_sexp_clos size env clos |> Sexp.to_string_hum
let pp_env env = Sexp.List (List.map to_sexp env) |> Sexp.to_string_hum
