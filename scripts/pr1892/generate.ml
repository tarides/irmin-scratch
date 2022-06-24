(* Store generated for the tests in https://github.com/mirage/irmin/pull/1892, with irmin.3.2.0. *)

include Lwt.Syntax

let root = "osef"
let indexing_strategy = Irmin_pack.Indexing_strategy.always

let stop_after_preload = false


(* let root = "version_3_always"
 * let indexing_strategy = Irmin_pack.Indexing_strategy.always *)

(* let root = "version_3_minimal"
 * let indexing_strategy = Irmin_pack.Indexing_strategy.minimal *)

(* let root = "version_2_minimal"
 * let indexing_strategy = Irmin_pack.Pack_store.Indexing_strategy.minimal *)

(* let root = "version_2_always"
 * let indexing_strategy = Irmin_pack.Pack_store.Indexing_strategy.always *)

module Conf = Irmin_tezos.Conf

module Schema = struct
  open Irmin
  module Metadata = Metadata.None
  module Contents = Contents.String_v2
  module Path = Path.String_list
  module Branch = Branch.String
  module Hash = Hash.SHA1
  module Node = Node.Generic_key.Make_v2 (Hash) (Path) (Metadata)
  module Commit = Commit.Generic_key.Make_v2 (Hash)
  module Info = Info.Default
end

module S = struct
  module Maker = Irmin_pack_unix.Maker (Conf)
  include Maker.Make (Schema)
end

let pp_hash = Repr.pp Schema.Hash.t

module Int63 = Optint.Int63

let config ?(readonly = false) ?(fresh = true) root =
  Irmin_pack.config ~readonly ~lru_size:0 ~fresh ~indexing_strategy root

let all_steps : (string, int) Hashtbl.t = Hashtbl.create 42

let register_dict_entry s =
  match Hashtbl.find_opt all_steps s with
  | Some _ -> ()
  | None -> Hashtbl.add all_steps s (Hashtbl.length all_steps)

let all_entries = Hashtbl.create 42

let dump_key  name k kind =
  Hashtbl.add all_entries name k;
  let open Irmin_pack.Pack_key in
  match inspect k with
  | Indexed _ -> assert false
  | Direct { hash; offset; length } ->
      Fmt.epr "let %s = {h=h(\"%a\"); o=i(%d); l=%d; k=`%c}\n%!" name pp_hash hash
        (Int63.to_int offset) length kind

let put_borphan bstore =
  let+ k = S.Backend.Contents.add bstore "borphan" in
  dump_key "borphan" k 'b';
  k

let put_b01 bstore =
  let+ k = S.Backend.Contents.add bstore "b01" in
  dump_key "b01" k 'n';
  k

let put_n01 bstore nstore =
  let* k_b01 = put_b01 bstore in
  let step = "step-b01" in
  register_dict_entry step;
  let childs = [ (step, `Contents (k_b01, ())) ] in
  let n = S.Backend.Node.Val.of_list childs in
  let+ k = S.Backend.Node.add nstore n in
  dump_key "n01" k 'n';
  k

let put_n0 bstore nstore =
  let* k_n01 = put_n01 bstore nstore in
  let step = "step-n01" in
  register_dict_entry step;
  let childs = [ (step, `Contents (k_n01, ())) ] in
  let n = S.Backend.Node.Val.of_list childs in
  let+ k = S.Backend.Node.add nstore n in
  dump_key "n0" k 'n';
  k

let put_c0 bstore nstore cstore =
  let* k_n0 = put_n0 bstore nstore in
  let c = S.Backend.Commit.Val.v ~info:S.Info.empty ~node:k_n0 ~parents:[] in
  let+ k = S.Backend.Commit.add cstore c in
  dump_key "c0" k 'c';
  k

let put_b1 bstore =
  let+ k = S.Backend.Contents.add bstore "b1" in
  dump_key "b1" k 'b';
  k

let put_n1 bstore nstore =
  let* k_b1 = put_b1 bstore in
  let k_n01 = Hashtbl.find all_entries "n01" in
  let step = "step-b1" in
  register_dict_entry step;
  let step' = "step-b01" in
  register_dict_entry step';
  let childs =
    [ (step, `Contents (k_b1, ())); (step', `Contents (k_n01, ())) ]
  in
  let n = S.Backend.Node.Val.of_list childs in
  let+ k = S.Backend.Node.add nstore n in
  dump_key "n1" k 'n';
  k

let put_c1 bstore nstore cstore =
  let* k_n1 = put_n1 bstore nstore in
  let k_c0 = Hashtbl.find all_entries "c0" in
  let c =
    S.Backend.Commit.Val.v ~info:S.Info.empty ~node:k_n1 ~parents:[ k_c0 ]
  in
  let+ k = S.Backend.Commit.add cstore c in
  dump_key "c1" k 'c';
  k

let put_borphan' bstore =
  let+ k = S.Backend.Contents.add bstore "borphan'" in
  dump_key "borphan'" k 'b';
  k

let put_b2 bstore =
  let+ k = S.Backend.Contents.add bstore "b2" in
  dump_key "b2" k 'b';
  k

let put_n2 bstore nstore =
  let* k_b2 = put_b2 bstore in
  let step = "step-b2" in
  register_dict_entry step;
  let childs = [ (step, `Contents (k_b2, ())) ] in
  let n = S.Backend.Node.Val.of_list childs in
  let+ k = S.Backend.Node.add nstore n in
  dump_key "n2" k 'n';
  k

let put_c2 bstore nstore cstore =
  let* k_n2 = put_n2 bstore nstore in
  let k_c1 = Hashtbl.find all_entries "c1" in
  let c =
    S.Backend.Commit.Val.v ~info:S.Info.empty ~node:k_n2 ~parents:[ k_c1 ]
  in
  let+ k = S.Backend.Commit.add cstore c in
  dump_key "c2" k 'c';
  k

let put_all repo =
  S.Backend.Repo.batch repo (fun bstore nstore cstore ->
      let* _ = put_borphan bstore in
      let* _ = put_c0 bstore nstore cstore in
      if not stop_after_preload then
        let* _ = put_c1 bstore nstore cstore in
        let* _ = put_borphan' bstore in
        let* _ = put_c2 bstore nstore cstore in
        Lwt.return_unit
      else Lwt.return_unit)

let main () =
  let config = config ~readonly:false ~fresh:true root in
  let* repo = S.Repo.v config in

  let* () = put_all repo in

  Fmt.epr "let pack_entries = [";
  Hashtbl.iter (fun s _ -> Fmt.epr "%s;" s) all_entries;
  Fmt.epr "]\n%!";

  Fmt.epr "let dict_entries = [";
  Hashtbl.iter (fun s i -> Fmt.epr "(%S,%d);" s i) all_steps;
  Fmt.epr "]\n%!";
  let* () = S.Repo.close repo in
  Lwt.return_unit

let () = Lwt_main.run (main ())
