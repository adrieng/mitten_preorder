open Mode_theory
type env_entry =
    Term of {term : Domain.t; mu : m; tp : Domain.t; md : mode}
  | TopLevel of {term : Domain.t; tp : Domain.t; md : mode}
  | M of m
type env = env_entry list

val env_to_sem_env : env -> Domain.env

module Error : sig
  type kind =
    | Cannot_synth_term of Syntax.t
    | Type_mismatch of Domain.t * Domain.t
    | Expecting_universe of Domain.t
    | Unbound_variable of Concrete_syntax.ident
    | Incompatible_modes of mode * mode
    | Incompatible_modalities of m * m
    | Cannot_coerce of m * m
    | Internal of string

  type t = kind Located.t

  exception E of t

  val raise : ?source:Span.t -> kind -> 'a

  val internal : string -> 'a

  val pp : t Printer.t
end

val check : env:env -> size:int -> term:Syntax.t -> tp:Domain.t -> m:mode -> unit
val synth : env:env -> size:int -> term:Syntax.t -> m:mode -> Domain.t
val check_tp : env:env -> size:int -> term:Syntax.t -> m:mode -> unit
