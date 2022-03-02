#load "str.cma"

#load "unix.cma"

(* To test in Cygwin:

   0. Install `jq` in Cygwin
   1. Change the current directory to be vendor/diskuv-ocaml (the directory containing .dkmlroot)
   2. Run the following (replace DV_WindowsMsvcDockerImage with what is in DeploymentVersion.psm1):

     DV_WindowsMsvcDockerImage="ocaml/opam:windows-msvc-20H2-ocaml-4.12@sha256:810ce2fca08c22ea1bf4066cb75ffcba2f98142d6ce09162905d9ddc09967da8" ; DOCKERARCH=amd64; OCAMLVERSION=4.12.1 ; DEPLOYDIR=$(cygpath -am $TMP/oorepo) ; CI_PROJECT_DIR=$(cygpath -am .) ; env TOPDIR=$CI_PROJECT_DIR/vendor/dkml-runtime-common/all/emptytop $CI_PROJECT_DIR/installtime/unix/private/reproducible-fetch-ocaml-opam-repo-1-setup.sh -d $CI_PROJECT_DIR -t $DEPLOYDIR -v $DV_WindowsMsvcDockerImage -a $DOCKERARCH -b $OCAMLVERSION

   3. Run:

     (cd $DEPLOYDIR ; share/dkml/repro/200-fetch-oorepo-$OCAMLVERSION/installtime/unix/private/reproducible-fetch-ocaml-opam-repo-2-build-noargs.sh)
     (cd $DEPLOYDIR ; share/dkml/repro/200-fetch-oorepo-$OCAMLVERSION/installtime/unix/private/reproducible-fetch-ocaml-opam-repo-9-trim-noargs.sh)
     OCAMLRUNPARAM=b ocaml $DEPLOYDIR/share/dkml/repro/200-fetch-oorepo-$OCAMLVERSION/installtime/unix/private/ml/ocaml_opam_repo_trim.ml -t $DEPLOYDIR -a $DOCKERARCH -b $OCAMLVERSION -n
*)

(* = CONSTANTS *)

type ocaml_version = OCAMLV4_12_0 | OCAMLV4_12_1 | OCAMLV4_13_1

(* Compiler specific package versions.
   These are required for the compiler version DKML supports.

   These package versions are _only_ for fdopen repository.
*)

let get_pkgvers_fdopen_compiler_specific = function
  | OCAMLV4_12_0 ->
      [
        ("camlp4", "4.12+system");
        ("merlin", "4.3.1-412");
        ("ocaml", "4.12.0");
        ("ocamlbrowser", "4.12.0");
        ("ocaml-src", "4.12.0");
      ]
  | OCAMLV4_12_1 ->
      [
        ("camlp4", "4.12+system");
        ("merlin", "4.3.1-412");
        ("ocaml", "4.12.1");
        ("ocamlbrowser", "4.12.0");
        ("ocaml-src", "4.12.1");
      ]
  | OCAMLV4_13_1 ->
      [
        ("camlp4", "4.13+system");
        ("merlin", "4.3.2~4.13preview");
        ("ocaml", "4.13.1");
        ("ocamlbrowser", "4.13.0") (* not a typo! 4.13.0 is latest *);
        ("ocaml-src", "4.13.1");
      ]

(* Compiler agnostic package versions.

   These package versions are _only_ for fdopen repository.
*)

let pkgvers_fdopen_compiler_agnostic =
  [
    (* The first section:
       * These are packages that are pinned because they are not lexographically the latest *)
    ("seq", "base");
    (* Second section: Any dependencies in fdopen that we need to resolve a particular version *)
    (*    dose3.5.0.1: opam 2.1.0 requirement *)
    ("dose3", "5.0.1-1");
    (*    extlib.X.Y.Z-M: unclear why we need this pinned *)
    ("extlib", "1.7.7-1");
  ]

let packages_fdopen_to_remove =
  [
    (* The first section is where we don't care what pkg version is used, but we know we don't want fdopen's version:
       * depext is unnecessary as of Opam 2.1
       * ocaml-compiler-libs,v0.12.4 and jst-config,v0.14.1 and dune-build-info,2.9.1 are part of the good set, but not part of the fdopen repository snapshot. So we remove it in
         reproducible-fetch-ocaml-opam-repo-9-trim.sh so the default Opam repository is used.
    *)
    "depext";
    "dune-build-info";
    "jst-config";
    "ocaml-compiler-libs";
    (* The second section is where we need all the DKML patched package versions for:
       * ocaml-variants since which package to choose is an install-time calculation (32/64 bit, dkml/dksdk, 4.12.1/4.13.1)
    *)
    "ocaml-variants";
    (* 3rd section corresponds to:
       * PINNED_PACKAGES_DKML_PATCHES in installtime\unix\create-opam-switch.sh
       and MUST BE IN SYNC.
    *)
    "ocamlfind";
    "ptime";
    "ocp-indent";
    "bigstringaf";
    "core_kernel";
    "ctypes-foreign";
    "ctypes";
    "digestif";
    "dune-configurator";
    "feather";
    "mirage-crypto-ec";
    "mirage-crypto-pk";
    "mirage-crypto-rng-async";
    "mirage-crypto-rng-mirage";
    "mirage-crypto-rng";
    "mirage-crypto";
    "ocamlbuild";
    "ppx_expect";
    (* 4th section corresponds to:
       * PINNED_PACKAGES_OPAM in installtime\unix\create-opam-switch.sh
       and MUST BE IN SYNC.
    *)
    "bos";
    "fmt";
    "rresult";
    "sha";
    "sexplib";
    "cmdliner";
    "jingoo";
    "lsp";
    "ocaml-lsp-server";
    "jsonrpc";
    "ocamlformat";
    "ocamlformat-rpc";
    "ocamlformat-rpc-lib";
    "odoc-parser";
    "stdio";
    "base";
    "dune";
    "utop";
    "ppxlib";
    "alcotest";
    "alcotest-async";
    "alcotest-js";
    "alcotest-lwt";
    "alcotest-mirage";
  ]

(* = ARGUMENT PROCESSING = *)

let usage_msg =
  "ocaml-opam-repo-trim -t DIR -a ARCH -b OCAMLVERSION [-n] [-p PACKAGE]"

let targetdir = ref ""

let dockerarch = ref ""

let ocamlversion_s = ref ""

let dryrun = ref false

let package = ref ""

let anon_fun (_ : string) = ()

let speclist =
  [
    ("-t", Arg.Set_string targetdir, "Target directory");
    ("-p", Arg.Set_string package, "Consider only the named package");
    ( "-a",
      Arg.Set_string dockerarch,
      "Docker architecture that was downloaded. Ex. amd64" );
    ("-b", Arg.Set_string ocamlversion_s, "OCaml language version. Ex. 4.12.1");
    ("-n", Arg.Set dryrun, "Dry run");
  ]

let () =
  Arg.parse speclist anon_fun usage_msg;
  if !dockerarch = "" || !ocamlversion_s = "" then (
    prerr_string "FATAL: ";
    prerr_endline usage_msg;
    exit 1)

let ocamlversion =
  match !ocamlversion_s with
  | "4.12.0" -> OCAMLV4_12_0
  | "4.12.1" -> OCAMLV4_12_1
  | "4.13.1" -> OCAMLV4_13_1
  | _ ->
      raise
      @@ Invalid_argument
           (Printf.sprintf "OCaml version %s is not supported" !ocamlversion_s)

(* = Variables = *)

let oorepo_p =
  let ( / ) = Filename.concat in
  Filename.(!targetdir / "share" / "dkml" / "repro" / !ocamlversion_s)

let oorepo_packages_p =
  let ( / ) = Filename.concat in
  Filename.(oorepo_p / "packages")

let repodir_p =
  let ( / ) = Filename.concat in
  Filename.(!targetdir / "full-opam-root")

let basedir_in_full_opamroot_p =
  let ( / ) = Filename.concat in
  Filename.(repodir_p / Format.sprintf "msvc-%s" !dockerarch)

let pins : string array = [||]

(* = Functions = *)

(* [find_packages] gets the packages in the OOREPO repository.
   Ex. (alcotest ansicolor dune) *)
let find_packages () = Array.to_list @@ Sys.readdir oorepo_packages_p

(* [all_package_versions PKG PKG_LOC] are the versions of the specified package PKG in the PKG_LOC directory.
   Ex. (v0.14.0 v0.14.1) *)
let all_package_versions pkg pkg_loc =
  let prefix_search_for = String.concat "" [ pkg; "." ] in
  let length_search_for = String.length prefix_search_for in
  Array.to_list @@ Sys.readdir pkg_loc
  |> List.filter_map (fun s ->
         if String.length s <= length_search_for then None
         else
           let prefix = String.sub s 0 length_search_for in
           if prefix = prefix_search_for then
             Some
               (String.sub s length_search_for
                  (String.length s - length_search_for))
           else None)

(* [semver VER] converts the version VER into a lexographically sortable string.
   The output format was designed to be easy when parsing.
   The goal is not to be a perfect semver parser; instead the goal is to pick out the highest version number.
   Ex. VER=v0.14.1        -> 0000000000_0000000014_0000000001_v0.14.1
   Ex. VER=20150820       -> 0020150820_0000000000_0000000000_20150820
   Ex. VER=0.9.6-4        -> 0000000000_0000000009_0000000006_0.9.6-4
   Ex. VER=3.0.0-20150830 -> 0000000003_0000000000_0000000000_3.0.0-20150830
   Ex. VER=8.00~alpha05   -> 0000000008_0000000000_0000000000_8.00~alpha05
   Ex. VER=2.02pl1        -> 0000000002_0000000002_0000000000_2.02pl1
   Ex. VER=sk0.23-0.3.1   -> 0000000000_0000000023_0000000000_sk0.23-0.3.1
   Ex. VER=transition     -> 0000000000_0000000000_0000000000_transition (the example is depext. another is seq's "base" version)
   Ex. VER=4.10.2+flambda+mingw32c -> 0000000004_0000000010_0000000002_4.10.2+flambda+mingw32c *)
let semver ver =
  let open Str in
  let lst =
    ver
    (* convert 8.00~alpha05 -> 8.00 (when a number is followed by a non-number/non-dot, then the remainder is thrown away for semver comparison) *)
    |> replace_first (regexp "\\([0-9]\\)[^0-9.].*") "\\1"
    (* replace all non-numbers with spaces *)
    |> global_replace (regexp "[^0-9]") " "
    (* convert 08 00 05 -> 8 0 5 so no subsequent misinterpret as an octal number *)
    |> global_replace (regexp "\\b0+\\([0-9]\\)") "\\1"
    (* the 0 0 0 makes sure there are at least 3 array terms *)
    |> fun s ->
    String.concat " " [ s; "0"; "0"; "0" ]
    (* split terms by whitespace, ignoring whitespace at beginning or end *)
    |> split (regexp "[ \t]+")
  in
  Printf.sprintf "%010Ld_%010Ld_%010Ld_%s"
    (Int64.of_string @@ List.nth lst 0)
    (Int64.of_string @@ List.nth lst 1)
    (Int64.of_string @@ List.nth lst 2)
    ver

let assert_semver ver expected =
  let actual = semver ver in
  if not (String.equal actual expected) then
    raise
      (Invalid_argument
         (Printf.sprintf
            "The semver %s was expected to be '%s' but was instead '%s'" ver
            expected actual))

(* Inline test *)
let () =
  assert_semver "v0.14.1" "0000000000_0000000014_0000000001_v0.14.1";
  assert_semver "20150820" "0020150820_0000000000_0000000000_20150820";
  assert_semver "0.9.6-4" "0000000000_0000000009_0000000006_0.9.6-4";
  assert_semver "3.0.0-20150830"
    "0000000003_0000000000_0000000000_3.0.0-20150830";
  assert_semver "8.00~alpha05" "0000000008_0000000000_0000000000_8.00~alpha05";
  assert_semver "2.02pl1" "0000000002_0000000002_0000000000_2.02pl1";
  assert_semver "sk0.23-0.3.1" "0000000000_0000000023_0000000000_sk0.23-0.3.1";
  assert_semver "transition" "0000000000_0000000000_0000000000_transition";
  assert_semver "4.10.2+flambda+mingw32c"
    "0000000004_0000000010_0000000002_4.10.2+flambda+mingw32c"

let read_whole_file filename =
  let ch = open_in_bin filename in
  let s = really_input_string ch (in_channel_length ch) in
  close_in ch;
  s

let find_latest_package_version pkg pkg_loc =
  let all_vers = all_package_versions pkg pkg_loc in
  let pp_lst = Format.(pp_print_list ~pp_sep:pp_print_space pp_print_string) in
  Format.(printf "[%s] Considering versions: @[%a@]@\n" pkg pp_lst all_vers);
  (* 1. only respect version directories that have an 'opam' file. Ex. frama-c-base.20160502 does not have one.
     2. only respect Jane Street packages that start with a 'v' (like v0.14.0), rather than 113.33.03. Ex. core.113.33.03
  *)
  let is_jane_street_pkg opam_loc =
    let opam_contents = read_whole_file opam_loc in
    try
      Str.(
        search_forward
          (regexp_string "homepage: \"https://github.com/janestreet/")
          opam_contents 0)
      >= 0
    with Not_found -> false
  in
  let plausible_ver_plus_semver_pairs =
    List.filter_map
      (fun ver ->
        let pkg_ver_loc =
          Filename.concat pkg_loc @@ String.concat "." [ pkg; ver ]
        in
        let opam_loc = Filename.concat pkg_ver_loc "opam" in
        match Sys.file_exists opam_loc with
        | true ->
            if
              String.length ver > 1
              && ver.[0] != 'v'
              && is_jane_street_pkg opam_loc
            then (
              Format.printf
                "[%s] Skipping version %-20s because it is a Jane Street \
                 package with a version that does not start with 'v'@\n"
                pkg ver;
              None)
            else Some (ver, semver ver)
        | false ->
            Format.printf
              "[%s] Skipping version %-20s because it has no opam file@\n" pkg
              ver;
            None)
      all_vers
  in
  let sorted_desc_plausible_ver_plus_semver_pairs =
    List.fast_sort
      (fun (a_ver, a_semver) (b_ver, b_semver) ->
        Int.neg @@ String.compare a_semver b_semver)
      plausible_ver_plus_semver_pairs
  in
  Format.(
    printf "[%s] Plausible semantic versions: @[%a@]@\n" pkg pp_lst
      (List.map
         (fun (a_ver, a_semver) -> a_semver)
         sorted_desc_plausible_ver_plus_semver_pairs));
  match sorted_desc_plausible_ver_plus_semver_pairs with
  | (fst_ver, fst_semver) :: rst -> Some fst_ver
  | _ -> None

let pkgvers_contains_package pkgvers pkg = List.mem_assoc pkg pkgvers

let remove_dir dir =
  let cmd =
    if Sys.win32 then Printf.(sprintf "rmdir \"%s\" /s /q" dir)
    else Printf.(sprintf "rm -rf '%s'" dir)
  in
  let status = Unix.system cmd in
  match status with
  | WEXITED 0 -> ()
  | WEXITED ec ->
      raise @@ Invalid_argument Printf.(sprintf "%s returned %d" cmd ec)
  | WSIGNALED killc ->
      raise
      @@ Invalid_argument Printf.(sprintf "%s had kill signal %d" cmd killc)
  | WSTOPPED stopc ->
      raise
      @@ Invalid_argument Printf.(sprintf "%s had stop signal %d" cmd stopc)

let trim_package pin_commands pkgvers_fdopen pkg =
  let pkg_loc = Filename.concat oorepo_packages_p pkg in
  if List.mem pkg packages_fdopen_to_remove then
    if !dryrun then
      Format.printf
        "[%s] Would have removed package at %s since on the fdopen to-remove \
         list@\n"
        pkg pkg_loc
    else (
      Format.printf
        "[%s] Removing package since on the fdopen to-remove list@\n" pkg;
      remove_dir pkg_loc)
  else
    let chosen_ver =
      match List.assoc_opt pkg pkgvers_fdopen with
      | Some ver ->
          Format.printf "[%s] Matches the fdopen package list@\n" pkg;
          Some ver
      | None -> find_latest_package_version pkg pkg_loc
    in
    match chosen_ver with
    | Some ver ->
        (if !dryrun then
         Format.printf
           "[%s] Would have chosen version %s and removed all others@\n" pkg ver
        else
          let pkg_dot_ver = String.concat "." [ pkg; ver ] in
          Format.printf "[%s] Chose version %s. Removing all others@\n" pkg ver;
          Sys.readdir pkg_loc |> Array.to_seq
          |> Seq.filter (fun s -> not @@ String.equal pkg_dot_ver s)
          |> Seq.iter (fun s -> remove_dir Filename.(concat pkg_loc s)));
        Queue.add
          Printf.(
            sprintf "opam pin add --yes --no-action -k version \"%s\" \"%s\""
              pkg ver)
          pin_commands
    | None ->
        if !dryrun then
          Format.printf
            "[%s] Would have removed package since no valid opam-containing \
             versions were found@\n"
            pkg
        else (
          Format.printf
            "[%s] Removing package since no valid opam-containing versions \
             were found@\n"
            pkg;
          remove_dir pkg_loc)

(* = Main loop = *)

let () =
  let packages = if !package = "" then find_packages () else [ !package ] in
  let pin_commands = Queue.create () in
  let pkgvers_fdopen =
    pkgvers_fdopen_compiler_agnostic
    @ get_pkgvers_fdopen_compiler_specific ocamlversion
  in
  List.iter (fun pkg -> trim_package pin_commands pkgvers_fdopen pkg) packages;
  let pin_loc = Filename.concat oorepo_p "pins.txt" in
  if !dryrun then (
    Format.printf "Would have added to %s@\n" pin_loc;
    Queue.iter (fun s -> Format.printf "  @[%s@]@\n" s) pin_commands)
  else
    (* WARNING: Cannot change the format of pins.txt without also changing diskuv-ocaml's
       installtime/unix/create-opam-switch.sh *)
    let oc = open_out_bin pin_loc in
    Queue.iter
      (fun s ->
        output_string oc s;
        output_char oc '\n')
      pin_commands;
    close_out oc
