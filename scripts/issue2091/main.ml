(* Macintosh HD:
 *
 *   Free: 74,82 GB (74 822 696 960 bytes)
 *   Capacity: 499,96 GB (499 963 174 912 bytes)
 *   Mount Point: /
 *   File System: APFS
 *   Writable: No
 *   Ignore Ownership: No
 *   BSD Name: disk1s6s1
 *   Volume UUID: 1C82E764-E300-4707-B5F9-CDF9C681C606
 *   Physical Drive:
 *       Device Name: APPLE SSD AP0512N
 *       Media Name: AppleAPFSMedia
 *       Medium Type: SSD
 *       Protocol: PCI-Express
 *       Internal: Yes
 *       Partition Map Type: Unknown
 *       S.M.A.R.T. Status: Verified *)

(* comanche: /dev/mapper/mega-irmin on /bench type ext4 (rw,relatime,stripe=320,data=ordered) *)

(* bench-gc: /dev/sda3 on / type ext4 (rw,relatime,errors=remount-ro) *)
(*
  ngoguey-mbp: macos APFS
  comanche: linux ext4
  bench-gc: linux ext4
 *)


let get_wtime () =
  Mtime_clock.now () |> Mtime.to_uint64_ns |> Int64.to_float |> ( *. ) 1e-9

let get_stime () = Rusage.((get Self).stime)
let get_utime () = Rusage.((get Self).utime)

type t = {
    wtime : float;
    stime : float;
    utime : float;
  }

let get_timings () =
  let wtime = get_wtime () in
  let stime = get_stime () in
  let utime = get_utime () in
  {wtime; stime; utime}

let sub t1 t0 =
  let wtime = t1.wtime -. t0.wtime in
  let stime = t1.stime -. t0.stime in
  let utime = t1.utime -. t0.utime in
  {wtime; stime; utime}

let add t1 t0 =
  let wtime = t1.wtime +. t0.wtime in
  let stime = t1.stime +. t0.stime in
  let utime = t1.utime +. t0.utime in
  {wtime; stime; utime}

let div_int t1 k =
  let k = float_of_int k in
  let wtime = t1.wtime /. k in
  let stime = t1.stime /. k in
  let utime = t1.utime /. k in
  {wtime; stime; utime}

let count_timings t0 =
  let t = get_timings () in
  let delta = sub t t0 in
  t, delta

let pp ppf {wtime; stime; utime } =
  Format.fprintf ppf "(w:%9.6f, s:%9.6f, u:%9.6f)" wtime stime utime

module Io = Irmin_pack_unix.Io.Unix
module Errs = Irmin_pack_unix.Io_errors.Make ( Io)

let dummy_size = 4096 * 100
let dummy = String.init dummy_size (fun _ -> Random.int 127 |> char_of_int)

let make_file ~fsync path bytes =
  let io = Io.create ~path ~overwrite:true |> Errs.raise_if_error in
  let count =
    (bytes |> float_of_int) /. (float_of_int dummy_size) |> Float.ceil |> int_of_float
  in
  (* Fmt.epr "> Creating %s with size ~%#d with %d loops\n%!" path bytes count; *)
  for i = 0 to (count - 1) do
    (* let dummy = String.init dummy_size (fun _ -> Random.int 127 |> char_of_int) in *)
    Io.write_string io ~off:(Optint.Int63.of_int (dummy_size * i)) dummy |> Errs.raise_if_error
  done;
  if fsync then
    Io.fsync io |> Errs.raise_if_error;
  Io.close io |> Errs.raise_if_error;
  dummy_size * count

let hostname = Unix.gethostname ()

let test ~fsync ~ram_treatement ~remove_method asked =
  let file1 = "./file1" in
  let t0 = get_timings () in
  let size = make_file file1 ~fsync asked in
  (* Fmt.epr "* size asked:%#d, returned:%#d, st_size:%#d\n%!" asked size (Io.size_of_path file1 |> Errs.raise_if_error |> Optint.Int63.to_int); *)
  let _, delta = count_timings t0 in
  (* Fmt.epr "* Elapsed %a ()\n%!" pp delta; *)
  (* Fmt.epr "\n%!"; *)

  let () =
    match ram_treatement with
    | `Purged | `Purged_and_touched ->
       let cmd = if hostname = "ngoguey-mbp" then "purge" else "bash -c 'sync ; echo 3 > /proc/sys/vm/drop_caches'" in
       (match Unix.open_process_in cmd |> Unix.close_process_in with
       | Unix.WEXITED 0 -> ()
       | _ -> assert false)
    | `None -> ()
  in

  (* Fmt.epr "> Touching a random set of pages\n%!"; *)
  let () =
    match ram_treatement with
    | `Purged_and_touched ->
       let rng = Random.State.make [| 42 |] in
       let io = Io.open_ ~path:file1 ~readonly:true |> Errs.raise_if_error in
       for _ = 0 to 10_000 do
         let off = (Random.State.float rng 0.9) *. (float_of_int size) |> Optint.Int63.of_float in
         let _ : string = Io.read_to_string io ~off ~len:1 |> Errs.raise_if_error in
         ()
       done;
       Io.close io |> Errs.raise_if_error;
    | `Purged | `None -> ()
  in

  (* Fmt.epr "> Calling GC\n%!"; *)
  for _ = 0 to 5 do
    Gc.full_major ()
  done;
  Gc.compact ();
  for _ = 0 to 5 do
    Gc.full_major ()
  done;
  (* Fmt.epr "\n%!"; *)

  (* Fmt.epr "> Go with test\n%!"; *)
  let t0 = get_timings () in

  (* Fmt.epr "Calling unlink\n%!"; *)
  (* Unix.unlink file1; *)
  (* Fmt.epr "Calling sleep\n%!"; *)
  (* let thread = Thread.create (fun () -> Sys.remove file1) () in *)
  let () =
    match remove_method with
    | `Sys_remove -> Sys.remove file1;
    | `Unix_unlink -> Unix.unlink file1;
  in
  (* Unix.sleepf 1.; *)
  (* Thread.join thread; *)

  let _, delta = count_timings t0 in

  delta

type row = {
    file_bytes : int;
    test_count : int;
    avg_unlink_duration_wall : float;
    avg_unlink_duration_user : float;
    avg_unlink_duration_sys : float;
    ram_treatement : [ `None | `Purged | `Purged_and_touched ];
    fsync : bool;
    (* clean_page_cache : bool; *)
    hostname : string;
    remove_method : [ `Sys_remove | `Unix_unlink ];
  } [@@deriving repr ~pp]

let tt asked ~fsync ~ram_treatement ~expected_loop_length ~remove_method =
  let time_budget = 11. in
  ignore expected_loop_length;
  (* let loops = time_budget /. expected_loop_length |> Float.ceil |> int_of_float in *)

  let t0 = get_timings () in
  let rec aux loop_idx acc =
    let newtimings = test ~fsync ~ram_treatement ~remove_method asked in
    let acc = add acc newtimings in
    let _, elapsed_since_started = count_timings t0 in
    if elapsed_since_started.wtime < time_budget then
      aux (loop_idx + 1) acc
    else
      (loop_idx + 1), acc
  in
  let loops, sum = aux 0 { wtime = 0.; utime = 0.; stime = 0.} in
  let delta = div_int sum loops in

  (* let _, bench_loop = count_timings t0 in *)
  (* let bench_loop = div_int bench_loop loops in *)

  let row = {
      file_bytes=asked;
      test_count=loops;
      avg_unlink_duration_wall=(delta.wtime |> ( *. ) 1e9 |> Float.round  |> ( *. ) 1e-9);
      avg_unlink_duration_user=(delta.utime |> ( *. ) 1e9 |> Float.round  |> ( *. ) 1e-9);
      avg_unlink_duration_sys=(delta.stime |> ( *. ) 1e9 |> Float.round  |> ( *. ) 1e-9);
      ram_treatement;
      fsync;
      (* clean_page_cache; *)
      hostname;
      remove_method;
    } in

  Fmt.pr "%a\n%!" (pp_row) row;

  (* Fmt.epr "unlinking %#14d bytes takes on average: %a. per bench loop: %a\n%!" asked pp delta pp bench_loop; *)
  ()

let () =
  Fmt.epr "> Hello World\n%!";

  let f ~fsync ~ram_treatement ~remove_method =
    let tt = tt ~fsync ~ram_treatement ~remove_method in
    tt     10_000_000 ~expected_loop_length:0.040923;
    tt     31_622_776 ~expected_loop_length:0.052251;
    tt    100_000_000 ~expected_loop_length:0.090917;
    tt    316_227_766 ~expected_loop_length:0.189146;
    tt  1_000_000_000 ~expected_loop_length:0.548990;
    tt  3_162_277_660 ~expected_loop_length:1.540797;
    tt 10_000_000_000 ~expected_loop_length:5.243284;
  in
  f  ~fsync:true ~ram_treatement:`Purged_and_touched ~remove_method:`Sys_remove;
  f  ~fsync:true ~ram_treatement:`Purged_and_touched ~remove_method:`Unix_unlink;
  f  ~fsync:true ~ram_treatement:`Purged ~remove_method:`Sys_remove;
  f  ~fsync:true ~ram_treatement:`Purged ~remove_method:`Unix_unlink;
  f  ~fsync:true ~ram_treatement:`None ~remove_method:`Sys_remove;
  f  ~fsync:true ~ram_treatement:`None ~remove_method:`Unix_unlink;
  f  ~fsync:false ~ram_treatement:`Purged_and_touched ~remove_method:`Sys_remove;
  f  ~fsync:false ~ram_treatement:`Purged_and_touched ~remove_method:`Unix_unlink;
  f  ~fsync:false ~ram_treatement:`Purged ~remove_method:`Sys_remove;
  f  ~fsync:false ~ram_treatement:`Purged ~remove_method:`Unix_unlink;
  f  ~fsync:false ~ram_treatement:`None ~remove_method:`Sys_remove;
  f  ~fsync:false ~ram_treatement:`None ~remove_method:`Unix_unlink;

  Fmt.epr "\n%!";
  Fmt.epr "> Bye World\n%!";
