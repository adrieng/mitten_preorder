type 'a t = { value : 'a; position : Span.t; }

let map f { value; position; } =
  { value = f value; position; }

let map_with_pos f { value; position; } =
  { value = f position value; position; }

let v x = x.value

let p x = x.position

let locate value start_p end_p = { value; position = Span.make start_p end_p; }

let locate_nowhere value = { value; position = Span.nowhere; }

type 'a fmt = Format.formatter -> 'a -> unit

let print pp fmt x=
  pp fmt x.value

let print_located pp fmt { value; position; } =
  Format.fprintf fmt "[<v 2>%a:@ %a@]" Span.print position pp value

let equal x y = x.value = y.value
