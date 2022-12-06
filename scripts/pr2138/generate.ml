(* Generate store with irmin.2.3.0 *)

let ( let* ) x f = Lwt.bind x f
let info () = Irmin.Info.empty

let reporter () =
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let with_stamp h _tags k fmt =
      let dt = Mtime.Span.to_us (Mtime_clock.elapsed ()) in
      Fmt.kpf k Fmt.stderr
        ("%+04.0fus %a %a @[" ^^ fmt ^^ "@]@.")
        dt
        Fmt.(styled `Magenta string)
        (Logs.Src.name src) Logs_fmt.pp_header (level, h)
    in
    msgf @@ fun ?header ?tags fmt -> with_stamp header tags k fmt
  in
  { Logs.report }

let () =
  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (reporter ())

module Conf = struct
  let entries = 32
  let stable_hash = 256
end

module H = Irmin.Hash.SHA1
module P = Irmin.Path.String_list

module Store =
  Irmin_pack.Make (Conf) (Irmin.Metadata.None) (Irmin.Contents.String) (P)
    (Irmin.Branch.String)
    (H)

module Private = Store.Private
module Index = Irmin_pack.Index.Make (H)

let generate_store_v1 = true

let main () =
  let root = if generate_store_v1 then "store_v1" else "store_v1_smaller" in
  let config = Irmin_pack.config root in
  let* repo = Store.Repo.v config in

  let* tree = Store.Tree.add Store.Tree.empty [ "a"; "d" ] "x" in
  let* _ = Store.Commit.v repo ~parents:[] ~info:(info ()) tree in

  let* tree = Store.Tree.add tree [ "a"; "b"; "c" ] "z" in
  let* c1 = Store.Commit.v repo ~parents:[] ~info:(info ()) tree in
  let* () = Store.Branch.set repo "bar" c1 in

  (* In order to generate the store "data/corrupted", create "store_v1_smaller"
     by not commiting this last commit. Then replace the index in
     "store_v1_smaller" with the one in "store_v1". This simulates a store where
     there are extra entries in the index that are not in the pack. *)
  let* () =
    if generate_store_v1 then
      let* tree = Store.Tree.add Store.Tree.empty [ "b" ] "y" in
      let* c2 = Store.Commit.v repo ~parents:[] ~info:(info ()) tree in
      Store.Branch.set repo "foo" c2
    else Lwt.return_unit
  in

  let* () = Store.Repo.close repo in

  (* Print the contents of the index. *)
  let index_old =
    Index.v ~fresh:false ~readonly:false ~log_size:500_000 "store_v1"
  in
  Index.iter
    (fun k (offset, length, kind) ->
      Fmt.epr "index find k = %a (off, len, kind) = (%d, %d, %c)\n"
        (Irmin.Type.pp H.t) k (Int64.to_int offset) length kind)
    index_old;
  Index.close index_old;
  Lwt.return_unit

let () = Lwt_main.run (main ())
