type 'a t = Format.formatter -> 'a -> unit

let string fmt s = Format.fprintf fmt "%s" s

let sexp to_sexp fmt x = Sexplib.Sexp.pp_hum fmt (to_sexp x)

let to_string pp x =
  ignore (Format.flush_str_formatter ());
  Format.fprintf Format.str_formatter "%a@?" pp x;
  Format.flush_str_formatter ()
