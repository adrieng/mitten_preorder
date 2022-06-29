module CS = Concrete_syntax
module S = Syntax
module D = Domain
module M = Mode_theory

type ident = CS.ident

type env = Env of {size : int; check_env : Check.env; bindings : ident list}

let initial_env = Env {size = 0; check_env = []; bindings = []}

type output =
    NoOutput of env
  | NF_term of S.t * S.t
  | NF_def of ident * S.t
  | Quit

let update_env env = function
  | NoOutput env -> env
  | NF_term _ | NF_def _ | Quit -> env

let output (Env {bindings; _}) = function
  | NoOutput _ -> ()
  | NF_term (s, t) ->
    let open Sexplib in
    let s_rep = Syntax.to_sexp (List.map (fun x -> Sexp.Atom x) bindings) s in
    Format.printf "@[<v 2>Computed normal form of %a@ as@ %a@]@."
      Sexp.pp_hum s_rep
      S.pp t
  | NF_def (name, t) ->
     Format.printf "@[<v 2>Computed normal form of [%s]:@ %a@]@."
       name
       S.pp t
  | Quit -> exit 0

let find_idx source key =
  let rec go i = function
    | [] -> Check.Error.(raise ~source (Unbound_variable key))
    | x :: xs -> if x = key then i else go (i + 1) xs in
  go 0

let rec int_to_term_desc = function
  | 0 -> S.Zero
  | n -> S.Suc (Located.locate_nowhere (int_to_term_desc (n - 1)))

let rec unravel_spine f = function
  | [] -> f
  | x :: xs -> unravel_spine (x f) xs

let rec bind_desc env position = function
  | CS.Var i -> S.Var (find_idx position i env)
  | CS.Let (tp, Binder {name; body}) ->
    S.Let (bind env tp, bind (name :: env) body)
  | CS.Check {term; tp} -> S.Check (bind env term, bind env tp)
  | CS.Nat -> S.Nat
  | CS.Suc t -> S.Suc (bind env t)
  | CS.Lit i -> int_to_term_desc i
  | CS.NRec
      { mot = Binder {name = mot_name; body = mot_body};
        zero;
        suc = Binder2 {name1 = suc_name1; name2 = suc_name2; body = suc_body};
        nat} ->
    S.NRec
      (bind (mot_name :: env) mot_body,
       bind env zero,
       bind (suc_name2 :: suc_name1 :: env) suc_body,
       bind env nat)
  | CS.Pi (mu, src, Binder {name; body}) -> S.Pi (M.bind_m mu, bind env src, bind (name :: env) body)
  | CS.Lam (BinderN {names = []; body}) ->
     Located.v @@ bind env body
  | CS.Lam (BinderN {names = x :: names; body}) ->
    let lam = Located.locate_nowhere (CS.Lam (BinderN {names; body})) in
    S.Lam (bind (x :: env) lam)
  | CS.Ap (f, args) ->
     let mk (mu, t) f =
       Located.locate_nowhere (S.Ap (M.bind_m mu, f, bind env t))
     in
     List.map mk args |> unravel_spine (bind env f) |> Located.v
  | CS.Sig (tp, Binder {name; body}) ->
    S.Sig (bind env tp, bind (name :: env) body)
  | CS.Pair (l, r) -> S.Pair (bind env l, bind env r)
  | CS.Fst p -> S.Fst (bind env p)
  | CS.Snd p -> S.Snd (bind env p)
  | CS.J
      {mot = Binder3 {name1 = left; name2 = right; name3 = prf; body = mot_body};
       refl = Binder {name = refl_name; body = refl_body};
       eq} ->
    S.J
      (bind (prf :: right :: left :: env) mot_body,
       bind (refl_name :: env) refl_body,
       bind env eq)
  | CS.Id (tp, left, right) ->
    S.Id (bind env tp, bind env left, bind env right)
  | CS.Refl t -> S.Refl (bind env t)
  | CS.Uni i -> S.Uni i
  | CS.TyMod (mu, tp) -> S.TyMod (M.bind_m mu, bind env tp)
  | CS.Mod (mu, tp) -> S.Mod (M.bind_m mu, bind env tp)
  | CS.Letmod (mu, nu, Binder {name; body}, Binder {name = name1; body = body1}, tp) ->
    S.Letmod (M.bind_m mu, M.bind_m nu, bind (name :: env) body, bind (name1 :: env) body1, bind env tp)

and bind env t = Located.map_with_pos (bind_desc env) t

let process_decl (Env {size; check_env; bindings}) t =
  match t.Located.value with
  | CS.Def {name; def; tp; md} ->
    let bind_md = M.bind_mode md in
    let def = bind bindings def in
    let tp = bind bindings tp in
    Check.check_tp ~size ~env:check_env ~term:tp ~m:bind_md;
    let sem_env = Check.env_to_sem_env check_env in
    let sem_tp = Nbe.eval tp sem_env in
    Check.check ~size ~env:check_env ~term:def ~tp:sem_tp ~m:bind_md;
    let sem_def = Nbe.eval def sem_env in
    let new_entry = Check.TopLevel {term = sem_def; tp = sem_tp; md = bind_md} in
    NoOutput (Env {size = size + 1; check_env = new_entry :: check_env; bindings = name :: bindings })
  | CS.NormalizeDef name ->
    let err = Check.Error.(raise (Unbound_variable name)) in
    begin
      let idx = find_idx t.Located.position name bindings in
      match List.nth check_env idx with
      | Check.TopLevel {term; tp; md = _} -> NF_def (name, Nbe.read_back_nf 0 (D.Normal {term; tp}))
      | _ -> raise err
      | exception Failure _ -> raise err
    end
  | CS.NormalizeTerm {term; tp; md} ->
    let bind_md = M.bind_mode md in
    let term = bind bindings term in
    let tp = bind bindings tp in
    Check.check_tp ~size ~env:check_env ~term:tp ~m:bind_md;
    let sem_env = Check.env_to_sem_env check_env in
    let sem_tp = Nbe.eval tp sem_env in
    Check.check ~size ~env:check_env ~term ~tp:sem_tp ~m:bind_md;
    let sem_term = Nbe.eval term sem_env in
    let norm_term = Nbe.read_back_nf 0 (D.Normal {term = sem_term; tp = sem_tp}) in
    NF_term (term, norm_term)
  | CS.Axiom {name; tp; md} ->
    let bound_md = M.bind_mode md in
    let tp = bind bindings tp in
    Check.check_tp ~size ~env:check_env ~term:tp ~m:bound_md;
    let sem_env = Check.env_to_sem_env check_env in
    let sem_tp = Nbe.eval tp sem_env in
    let new_entry = Check.TopLevel {term = D.Neutral {tp = sem_tp; term = D.Axiom (name, sem_tp)}; tp = sem_tp; md = bound_md} in
    NoOutput (Env {size = size + 1; check_env = new_entry :: check_env; bindings = name :: bindings })
  | CS.Quit -> Quit

let rec process_sign ?env = function
  | [] -> ()
  | d :: ds ->
    let env = match env with
        None -> initial_env
      | Some e -> e in
    let o = process_decl env d in
    output env o;
    process_sign ?env:(Some (update_env env o)) ds
