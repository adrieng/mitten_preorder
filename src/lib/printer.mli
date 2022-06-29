type 'a t = Format.formatter -> 'a -> unit

val string : string t

val sexp : ('a -> Sexplib.Sexp.t) -> 'a t

val to_string : 'a t -> 'a -> string
