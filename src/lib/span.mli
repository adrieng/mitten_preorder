(** An area between two positions in a source file. *)
type t

val make : Lexing.position -> Lexing.position -> t

val nowhere : t

val print : Format.formatter -> t -> unit

val join : t -> t -> t

val joinl : t list -> t
