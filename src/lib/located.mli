type 'a t = { value : 'a; position : Span.t; }

val map : ('a -> 'b) -> 'a t -> 'b t

val map_with_pos : (Span.t -> 'a -> 'b) -> 'a t -> 'b t

val v : 'a t -> 'a

val p : 'a t -> Span.t

val locate : 'a -> Lexing.position -> Lexing.position -> 'a t

val locate_nowhere : 'a -> 'a t

type 'a fmt = Format.formatter -> 'a -> unit

val print : 'a fmt -> 'a t fmt

val print_located : 'a fmt -> 'a t fmt

val equal : 'a t -> 'a t -> bool
