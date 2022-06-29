type pos = int * int          (** Line number and character position in line. *)

let pos_of_lexpos lpos = Lexing.(lpos.pos_lnum, lpos.pos_cnum - lpos.pos_bol)

let min_lex (l1, c1) (l2, c2) =
  if l1 < l2 then (l1, c1)
  else if l1 > l2 then (l2, c2)
  else (l1, min c1 c2)

let max_lex (l1, c1) (l2, c2) =
  if l1 < l2 then (l2, c2)
  else if l1 > l2 then (l1, c1)
  else (l1, max c1 c2)

type t = { fname : string; beg_pos : pos; end_pos : pos; }

let pick_fname fname1 fname2 =
  match fname1, fname2 with
  | "", "" -> "*unknown*"
  | _, "" -> fname1
  | "", _ -> fname2
  | _ -> fname1                  (* arbitrary choice *)

let make beg_p end_p =
  let open Lexing in
  { fname = pick_fname beg_p.pos_fname end_p.pos_fname;
    beg_pos = pos_of_lexpos beg_p; end_pos = pos_of_lexpos end_p; }

let nowhere = { fname = ""; beg_pos = 0, 0; end_pos = 0, 0; }

let print fmt ({ fname;
                 beg_pos = (beg_lnum, beg_cnum);
                 end_pos = (end_lnum, end_cnum); } as pos) =
  if pos = nowhere then Format.fprintf fmt "*nowhere*"
  else if beg_lnum = end_lnum then
    Format.fprintf fmt "File \"%s\", line %d, characters %d-%d:"
      fname beg_lnum beg_cnum end_cnum
  else
    Format.fprintf fmt "File \"%s\", %d:%d-%d:%d:"
      fname beg_lnum beg_cnum end_lnum end_cnum

let join p1 p2 =
  if p1 = nowhere then p2
  else if p2 = nowhere then p1
  else { fname = pick_fname p1.fname p2.fname;
         beg_pos = min_lex p1.beg_pos p2.beg_pos;
         end_pos = max_lex p1.beg_pos p2.beg_pos; }

let joinl = List.fold_left join nowhere
