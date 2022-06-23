(* Store generated for the tests in https://github.com/mirage/irmin/pull/1892, with irmin.3.2.0. *)

include Lwt.Syntax

let store_v3 = "test-data"

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

let config ?(readonly = false) ?(fresh = true) root =
  let indexing_strategy= Irmin_pack.Pack_store.Indexing_strategy.always in
  Irmin_pack.config ~readonly ~lru_size:0 ~fresh ~indexing_strategy root

let preload_commit repo =
  let tree = S.Tree.empty () in
  let* tree = S.Tree.add tree [ "abba"; "abab" ] "x" in
  let* _ = S.Commit.v repo ~info:S.Info.empty ~parents:[] tree in
  Lwt.return_unit

let main () =
  let config = config ~readonly:false ~fresh:true store_v3 in
  let* repo = S.Repo.v config in
  let* () = preload_commit repo in
  let* () = S.Repo.close repo in
  Lwt.return_unit

let () = Lwt_main.run (main ())
