(* Things to plot


In the 2M tree, (almost) all Values are at depth 4
df[df.entry_count == 2008240][~df.is_branch].sort_values(['depth', 'pred_count'])

In [90]: # In the 2M tree, filling of branches is very good
    ...: d = df[df.entry_count == 2008240][df.is_branch]
    ...: d.totpred.sum() / d['count'].sum()
Out[90]: 27.43817999053926

In [92]: # In the 2M tree, filling of leaves is very bad
    ...: d = df[df.entry_count == 2008240][~df.is_branch]
    ...: d.totpred.sum() / d['count'].sum()
Out[92]: 2.2457355134940498

In [118]: # Filling is cyclically optimal. There is one ~700k and another ~22M
     ...: d = df.groupby(['entry_count', 'is_branch'])[['totpred', 'count']].sum().reset_index()
     ...: d['filling'] = d.totpred / d['count']
     ...: d[~d.is_branch]

 *)

type step = string
type t = Leaf of step list | Branch of t array | Empty
type conf = { branch_factor : int; leaf_factor : int }

let empty = Empty
let is_empty = function Empty -> true | _ -> false

let index : conf:_ -> depth:int -> string -> int =
 fun ~conf ~depth step -> Hashtbl.seeded_hash depth step mod conf.branch_factor

let rec add ~depth ~conf step t =
  match t with
  | Empty -> Leaf [ step ]
  | Leaf l when List.length l < conf.leaf_factor -> Leaf (step :: l)
  | Leaf l ->
      List.fold_left
        (fun t step -> add ~depth ~conf step t)
        (Branch (Array.make conf.branch_factor empty))
        (step :: l)
  | Branch arr as t ->
      let idx = index ~conf ~depth step in
      let old_cell = arr.(idx) in
      let new_cell = add ~depth:(depth + 1) ~conf step old_cell in
      arr.(idx) <- new_cell;
      t

let add = add ~depth:0

let pp t =
  let rec aux prefix = function
    | Empty ->
        assert (prefix = "| ");
        Printf.eprintf "| []\n"
    | Leaf l ->
        Printf.eprintf "%s[" prefix;
        List.iter (fun step -> Printf.eprintf "%s, " step) l;
        Printf.eprintf "]\n"
    | Branch arr ->
        Array.iteri
          (fun i t ->
            if not @@ is_empty t then (
              Printf.eprintf "%s%02d" prefix i;
              Printf.eprintf "\n";
              aux (prefix ^ "   ") t))
          arr
  in
  aux "| " t;
  Printf.eprintf "%!"

type key = { is_branch : bool; depth : int; pred_count : int }
type stats = { d : (key, int) Hashtbl.t }

let rec stats ~s ~depth t =
  if is_empty t then ()
  else
    let k, preds =
      match t with
      | Empty -> assert false
      | Leaf l -> ({ is_branch = false; depth; pred_count = List.length l }, [])
      | Branch arr ->
          let preds =
            Array.to_list arr |> List.filter (fun t -> not @@ is_empty t)
          in
          let k = { is_branch = true; depth; pred_count = List.length preds } in
          (k, preds)
    in
    let v = Hashtbl.find_opt s.d k |> Option.value ~default:0 in
    Hashtbl.replace s.d k (v + 1);
    List.iter (stats ~s ~depth:(depth + 1)) preds

let stats t =
  let s = { d = Hashtbl.create 0 } in
  stats ~s ~depth:0 t;
  s

let string_of_kv k v =
  Printf.sprintf "%d,%d,%d,%d" (Bool.to_int k.is_branch) k.depth k.pred_count v

let string_of_stats s =
  "is_branch,depth,pred_count,count\n"
  ^ (Hashtbl.to_seq s.d
    |> Seq.map (fun (k, v) -> string_of_kv k v ^ "\n")
    |> List.of_seq |> String.concat "")

let create ~conf entry_count =
  let steps = List.init entry_count string_of_int in
  List.fold_left (fun acc step -> add ~conf step acc) empty steps

(* str(sorted(set([int(i) for i in np.round(32 ** np.arange(6, 0, -1/16)[::-1])] + list(range(1, 32)) ) )) *)
let lengthts_to_test =
  [1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15; 16; 17; 18; 19; 20; 21; 22; 23; 24; 25; 26; 27; 28; 29; 30; 31; 32; 40; 49; 61; 76; 95; 117; 146; 181; 225; 279; 347; 431; 535; 664; 825; 1024; 1272; 1579; 1961; 2435; 3025; 3756; 4664; 5793; 7194; 8933; 11094; 13777; 17109; 21247; 26386; 32768; 40693; 50535; 62757; 77936; 96785; 120194; 149263; 185364; 230195; 285870; 355010; 440872; 547500; 679917; 844361; 1048576; 1302182; 1617125; 2008240; 2493948; 3097129; 3846194; 4776426; 5931642; 7366255; 9147842; 11360319; 14107901; 17520007; 21757357; 27019544; 33554432; 41669834; 51748008; 64263668; 79806339; 99108125; 123078199; 152845623; 189812531; 235720175; 292730940; 363530205; 451452825; 560640218; 696235434; 864625413; 1073741824] [@ocamlformat "disable"]

let _ =
  Printf.eprintf "Hello world\n%!";
  let conf = { branch_factor = 32; leaf_factor = 32 } in
  List.iter
    (fun length_to_test ->
      let path = Printf.sprintf "csv/%#013d" length_to_test in
      Printf.eprintf "%s\n%!" path;
      let t = create ~conf length_to_test in
      let s = stats t in
      let s = string_of_stats s in

      let chan = open_out path in
      output_string chan s;
      close_out chan;

      (* Printf.eprintf "%s\n%!" s; *)
      Printf.eprintf "\n%!")
    lengthts_to_test;
  Printf.eprintf "Bye world\n%!"

let _old _ =
  Printf.eprintf "Hello world\n%!";
  let conf = { branch_factor = 32; leaf_factor = 32 } in
  let t = create ~conf 2_000_000 in
  let s = stats t in
  let s = string_of_stats s in
  Printf.eprintf "%s\n%!" s;
  Printf.eprintf "Bye world\n%!";
  ignore t

let _old _ =
  let conf = { branch_factor = 2; leaf_factor = 2 } in
  let _ =
    List.init 10 (fun i ->
        Printf.eprintf "========= %d\n%!" i;
        let t = create ~conf i in
        pp t;
        let s = stats t in
        let s = string_of_stats s in
        Printf.eprintf "%s\n%!" s)
  in

  Printf.eprintf "Bye world\n%!"
