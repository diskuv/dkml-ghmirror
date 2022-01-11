(*
To setup on Unix/macOS:
  eval $(opam env --switch diskuv-host-tools --set-switch)
  # or: eval $(opam env) && opam install dune bos logs fmt sexplib sha
  opam install ocaml-lsp-server ocamlformat ocamlformat-rpc # optional, for vscode or emacs

To setup on Windows:
  1. Make sure $DiskuvOCamlHome/share/dkml/functions/crossplatform-functions.sh exists.
  2. Run in MSYS2:
    eval $(opam env --switch "$DiskuvOCamlHome/host-tools" --set-switch)

To test use x64-windows or arm64-osx for the DKML_VCPKG_HOST_TRIPLET (or leave that variable out):
    dune build installtime/msys2/apps/with-dkml/with_dkml.exe
    DKML_VCPKG_HOST_TRIPLET=x64-windows DKML_BUILD_TRACE=ON DKML_BUILD_TRACE_LEVEL=2 _build/default/installtime/msys2/apps/with-dkml/with_dkml.exe sleep 5
    DKML_3P_PROGRAM_PATH='H:/build/windows_x86/vcpkg_installed/x86-windows/debug;H:/build/windows_x86/vcpkg_installed/x86-windows' DKML_3P_PREFIX_PATH='H:/build/windows_x86/vcpkg_installed/x86-windows/debug;H:/build/windows_x86/vcpkg_installed/x86-windows' DKML_BUILD_TRACE=ON DKML_BUILD_TRACE_LEVEL=2 ./installtime/msys2/apps/_build/default/with-dkml/with_dkml.exe sleep 5
*)
open Bos
open Rresult
open Astring
open Sexplib
open Opam_context
open Vcpkg_context
open Dkml_apps_common
open Dkml_environment

let usage_msg = "with-dkml.exe CMD [ARGS...]\n"

(* [msvc_as_is_vars] is the list of environment variables created by VsDevCmd.bat that
   should always be inserted into the environment as-is.
*)
let msvc_as_is_vars =
  [
    "DevEnvDir";
    "ExtensionSdkDir";
    "Framework40Version";
    "FrameworkDir";
    "Framework64";
    "FrameworkVersion";
    "FrameworkVersion64";
    "INCLUDE";
    "LIB";
    "LIBPATH";
    "UCRTVersion";
    "UniversalCRTSdkDir";
    "VCIDEInstallDir";
    "VCINSTALLDIR";
    "VCToolsInstallDir";
    "VCToolsRedistDir";
    "VCToolsVersion";
    "VisualStudioVersion";
    "VS140COMNTOOLS";
    "VS150COMNTOOLS";
    "VS160COMNTOOLS";
    "VSINSTALLDIR";
    "WindowsLibPath";
    "WindowsSdkBinPath";
    "WindowsSdkDir";
    "WindowsSDKLibVersion";
    "WindowsSdkVerBinPath";
    "WindowsSDKVersion";
  ]

(* [autodetect_compiler_as_is_vars] is the list of environment variables created by autodetect_compiler
   in crossplatform-function.sh that should always be inserted into the environment as-is. *)
let autodetect_compiler_as_is_vars =
  [
    "MSVS_PREFERENCE";
    "CMAKE_GENERATOR_RECOMMENDED";
    "CMAKE_GENERATOR_INSTANCE_RECOMMENDED"
  ]

(** [prune_path_of_microsoft_visual_studio ()] removes all Microsoft Visual Studio entries from the environment
    variable PATH *)
let prune_path_of_microsoft_visual_studio () =
  OS.Env.req_var "PATH" >>= fun path ->
  String.cuts ~empty:false ~sep:";" path
  |> List.filter (fun entry ->
         let contains = path_contains entry in
         let ends_with = path_ends_with entry in
         not
           (ends_with "\\Common7\\IDE"
           || ends_with "\\Common7\\Tools"
           || ends_with "\\MSBuild\\Current\\Bin"
           || contains "\\VC\\Tools\\MSVC\\"
           || contains "\\Windows Kits\\10\\bin\\"
           || contains "\\Microsoft.NET\\Framework64\\"
           || contains "\\MSBuild\\Current\\bin\\"))
  |> fun paths -> Some (String.concat ~sep:";" paths) |> OS.Env.set_var "PATH"

(** [prune_envvar ~f ~path_sep varname] sets the environment variables named [varname] to
   be all the path entries that satisfy the predicate f.
   Path entries are separated from each other by [~path_sep].
   The order of the path entries is preserved.
*)
let prune_envvar ~f ~path_sep varname =
  let varvalue = OS.Env.opt_var varname ~absent:"" in
  if "" = varvalue then R.ok ()
  else
    String.cuts ~empty:false ~sep:path_sep varvalue
    |> List.filter f
    |> fun entries ->
    Some (String.concat ~sep:path_sep entries) |> OS.Env.set_var varname

(** Remove every MSVC environment variable from the environment and prune MSVC
    entries from the PATH environment variable. *)
let remove_microsoft_visual_studio_entries () =
  (* 1. Remove all as-is variables *)
  List.fold_right
    (fun varname acc ->
      match acc with Ok () -> OS.Env.set_var varname None | Error _ -> acc)
    (msvc_as_is_vars @ autodetect_compiler_as_is_vars) (Ok ())
  >>= fun () ->
  (* 2. Remove VSCMD_ variables *)
  OS.Env.current () >>= fun old_env ->
  String.Map.iter
    (fun varname _varvalue ->
      if String.is_prefix ~affix:"VSCMD_" varname then
        OS.Env.set_var varname None |> Rresult.R.error_msg_to_invalid_arg)
    old_env;

  (* 3. Remove MSVC entries from PATH *)
  prune_path_of_microsoft_visual_studio ()

(* [add_microsoft_visual_studio_entries ()] updates the environment to include
   Microsoft Visual Studio entries like LIB, INCLUDE and the others listed in
   [msvc_as_is_vars] and in [autodetect_compiler_as_is_vars]. Additionally PATH is updated.

   The PATH and DiskuvOCamlHome environment variables on entry are used as a cache key.

   If OPAM_SWITCH_PREFIX is not defined, then <dkmlhome_dir>/host-tools (the Diskuv
   System opam switch) is used instead.
*)
let set_msvc_entries cache_keys =
  OS.Env.req_var "PATH" >>= fun path ->
  let dkmlhome = OS.Env.opt_var "DiskuvOCamlHome" ~absent:"" in
  let cache_keys = path :: dkmlhome :: cache_keys in
  (* 1. Remove MSVC entries *)
  remove_microsoft_visual_studio_entries () >>= fun () ->
  (* 2. Add MSVC entries *)
  Lazy.force get_msys2_dir_opt >>= function
  | None -> R.ok cache_keys
  | Some msys2_dir -> (
      Lazy.force get_dkmlhome_dir >>= fun dkmlhome_dir ->
      let do_set setvars =
        List.iter
          (fun (varname, varvalue) ->
            if varname = "PATH_COMPILER" then (
              OS.Env.set_var "PATH" (Some (varvalue ^ ";" ^ path))
              |> Rresult.R.error_msg_to_invalid_arg;
              Logs.debug (fun m ->
                m "Prepending PATH_COMPILER to PATH. (prefix <|> existing) = (%s <|> %s)" varvalue path)
            )
            else (
              OS.Env.set_var varname (Some varvalue)
              |> Rresult.R.error_msg_to_invalid_arg;
              Logs.debug (fun m ->
                m "Setting (name,value) = (%s,%s)" varname varvalue)
            )
          )
          (association_list_of_sexp setvars)
      in
      Lazy.force get_opam_switch_prefix >>= fun opam_switch_prefix ->
      let cache_dir = Fpath.(opam_switch_prefix / ".dkml" / "compiler-cache") in
      let cache_key =
        (* The cache keys may be:

           - deployment id (basically the version of DKML)
           - the vcpkg installation path (from DKML_VCPKG_HOST_TRIPLET/DKML_VCPKG_MANIFEST_DIR environment values)

           to which we add:

           - the PATH on entry to this function (minus any MSVC entries)
        *)
        let ctx = Sha256.init () in
        List.iter (fun key -> Sha256.update_string ctx key) cache_keys;
        Sha256.update_string ctx path;
        Sha256.(finalize ctx |> to_hex)
      in
      let cache_file = Fpath.(cache_dir / (cache_key ^ ".sexp")) in
      OS.File.exists cache_file >>= fun cache_hit ->
      if cache_hit then (
        (* Cache hit *)
        Logs.info (fun m ->
            m "Loading compiler cache entry %a" Fpath.pp cache_file);
        let setvars = Sexp.load_sexp (Fpath.to_string cache_file) in
        do_set setvars;
        Ok cache_keys)
      else
        (* Cache miss *)
        let cache_miss tmp_sexp_file _oc _v =
          let dash =
            Fpath.(msys2_dir / "usr" / "bin" / "dash.exe" |> to_string)
          in
          let crossplatfuncs =
            Fpath.(
              dkmlhome_dir / "share" / "dkml" / "functions"
              / "crossplatform-functions.sh"
              |> to_string)
          in

          let shell_expr =
            Fmt.str
              "__source=$(/usr/bin/cygpath -a '%s') && . $__source && \
               autodetect_compiler --sexp '%a'"
              crossplatfuncs Fpath.pp tmp_sexp_file
          in
          let cmd = Cmd.(v dash % "-c" % shell_expr) in

          (* Run the shell expression to autodetect the compiler *)
          (OS.Cmd.run_status cmd >>= function
           | `Exited status ->
               if status <> 0 then
                 Rresult.R.error_msgf
                   "Compiler autodetection failed with exit code %d" status
               else Rresult.R.ok ()
           | `Signaled signal ->
               (* https://stackoverflow.com/questions/1101957/are-there-any-standard-exit-status-codes-in-linux/1535733#1535733 *)
               exit (128 + signal))
          >>| fun () ->
          (* Read the compiler environment variables *)
          let env_vars =
            Sexp.load_sexp_conv_exn
              (Fpath.to_string tmp_sexp_file)
              association_list_of_sexp
          in
          Logs.debug (fun m -> m "autodetect_compiler output vars:@\n%a" Fmt.(list (Dump.pair string string)) env_vars);

          (* Store the as-is and PATH_COMPILER compiler environment variables in an association list *)
          let setvars =
            List.filter_map
              (fun varname ->
                match List.assoc_opt varname env_vars with
                | Some varvalue ->
                    Some Sexp.(List [ Atom varname; Atom varvalue ])
                | None -> None)
              ("PATH_COMPILER" :: (msvc_as_is_vars @ autodetect_compiler_as_is_vars))
          in
          Sexp.List setvars
        in

        match OS.File.with_tmp_oc "dkml-%s.tmp.sexp" cache_miss () with
        | Ok (Ok setvars) ->
            do_set setvars;

            (* Save the cache miss so it is a cache hit next time *)
            OS.Dir.create cache_dir >>= fun _already_exists ->
            Logs.info (fun m ->
                m "Saving compiler cache entry %a" Fpath.pp cache_file);

            Sexp.save_hum (Fpath.to_string cache_file) setvars;
            Ok cache_keys
        | Ok (Error _ as err) -> err
        | Error _ as err -> err)

(** [probe_os_path_sep] is a lazy function that looks at the PATH and determines what the PATH
    separator should be.
    We don't use [Sys.win32] except in an edge case, because [Sys.win32] will be true
    even inside MSYS2. Instead if any semicolon is in the PATH then the PATH separator
    must be [";"].
  *)
let probe_os_path_sep =
  lazy
    ( OS.Env.req_var "PATH" >>| fun path ->
      match
        ( String.find (fun c -> c = ';') path,
          String.find (fun c -> c = ':') path )
      with
      | None, None -> if Sys.win32 then ";" else ":"
      | None, Some _ -> ":"
      | Some _, _ -> ";" )

let prune_entries f =
  Lazy.force probe_os_path_sep >>= fun os_path_sep ->
  prune_envvar ~f ~path_sep:";" "INCLUDE" >>= fun () ->
  prune_envvar ~f ~path_sep:os_path_sep "CPATH" >>= fun () ->
  prune_envvar ~f ~path_sep:":" "COMPILER_PATH" >>= fun () ->
  prune_envvar ~f ~path_sep:";" "LIB" >>= fun () ->
  prune_envvar ~f ~path_sep:":" "LIBRARY_PATH" >>= fun () ->
  prune_envvar ~f ~path_sep:os_path_sep "PKG_CONFIG_PATH" >>= fun () ->
  prune_envvar ~f ~path_sep:os_path_sep "PATH"

let prepend_envvar ~path_sep varname dir = function
  | None -> OS.Env.set_var varname (Some dir)
  | Some v when "" = v -> OS.Env.set_var varname (Some dir)
  | Some v -> OS.Env.set_var varname (Some (dir ^ path_sep ^ v))

let prepend_entries ~tools installed_dir =
  Lazy.force probe_os_path_sep >>= fun os_path_sep ->
  let include_dir =
    Fpath.(installed_dir / "include" |> to_string)
  in
  OS.Env.parse "INCLUDE" OS.Env.(some string) ~absent:None
  >>= prepend_envvar ~path_sep:";" "INCLUDE" include_dir
  >>= fun () ->
  OS.Env.parse "CPATH" OS.Env.(some string) ~absent:None
  >>= prepend_envvar ~path_sep:os_path_sep "CPATH" include_dir
  >>= fun () ->
  OS.Env.parse "COMPILER_PATH" OS.Env.(some string) ~absent:None
  >>= prepend_envvar ~path_sep:":" "COMPILER_PATH" include_dir
  >>= fun () ->
  let lib_dir = Fpath.(installed_dir / "lib" |> to_string) in
  OS.Env.parse "LIB" OS.Env.(some string) ~absent:None
  >>= prepend_envvar ~path_sep:";" "LIB" lib_dir
  >>= fun () ->
  OS.Env.parse "LIBRARY_PATH" OS.Env.(some string) ~absent:None
  >>= prepend_envvar ~path_sep:":" "LIBRARY_PATH" lib_dir
  >>= fun () ->
  OS.Env.parse "PKG_CONFIG_PATH" OS.Env.(some string) ~absent:None
  >>= prepend_envvar ~path_sep:os_path_sep "PKG_CONFIG_PATH"
        Fpath.(installed_dir / "lib" / "pkgconfig" |> to_string)
  >>= fun () -> (
  if tools then (
  OS.Path.query Fpath.(installed_dir / "tools" / "$(tool)" / "$(file).exe")
  >>= fun matches ->
  R.ok (List.map (fun (_fp, pat) -> Astring.String.Map.get "tool" pat) matches)
  >>= fun tools_with_exe ->
  OS.Path.query Fpath.(installed_dir / "tools" / "$(tool)" / "$(file).dll")
  >>= fun matches ->
  R.ok (List.map (fun (_fp, pat) -> Astring.String.Map.get "tool" pat) matches)
  >>| fun tools_with_dll ->
  List.sort_uniq String.compare (tools_with_exe @ tools_with_dll))
  else (R.ok []))
  >>= fun uniq_tools ->
  let installed_path =
    Fpath.(installed_dir / "bin" |> to_string)
    ^ List.fold_left (fun acc b -> acc ^ os_path_sep ^ Fpath.(installed_dir / "tools" / b |> to_string)) "" uniq_tools
  in
  OS.Env.parse "PATH" OS.Env.(some string) ~absent:None
  >>= prepend_envvar ~path_sep:os_path_sep "PATH" installed_path

(* [set_3p_prefix_entries cache_keys] will modify MSVC/GCC/clang variables and PKG_CONFIG_PATH and PATH for
   each directory in the semicolon-separated environment variable DKML_3P_PREFIX_PATH.

  The CPATH, COMPILER_PATH, INCLUDE, LIBRARY_PATH, and LIB variables are modified so that
  when:

  - MSVC is used INCLUDE and LIB are picked up
    (https://docs.microsoft.com/en-us/cpp/build/reference/cl-environment-variables?view=msvc-160
    and https://docs.microsoft.com/en-us/cpp/build/reference/linking?view=msvc-160#link-environment-variables)
  - GCC is used COMPILER_PATH and LIBRARY_PATH are picked up
    (https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables)
  - clang is used CPATH and LIBRARY_PATH are picked up
    ( https://clang.llvm.org/docs/CommandGuide/clang.html and https://reviews.llvm.org/D65880)
 *)
let set_3p_prefix_entries cache_keys =
  let rec helper = function
  | [] -> R.ok ()
  | dir :: rst ->
    let null_possible_dir = R.ignore_error ~use:(fun _e -> OS.File.null) (Fpath.of_string dir) in
    if (Fpath.compare OS.File.null null_possible_dir = 0) then
      (* skip over user-submitted directory because it has some parse error *)
      helper rst
    else
      let threep = null_possible_dir in
      (* 1. Remove 3p entries, if any, from compiler variables and PKG_CONFIG_PATH.
          The gcc compiler variables COMPILER_PATH and LIBRARY_PATH are always colon-separated
          per https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables.
          This _might_ conflict with clang if clang were run on Windows (very very unlikely)
          because clang's CPATH is explicitly OS path separated; perhaps clang's LIBRARY_PATH is as
          well.
      *)
      let f = (fun entry -> let fp = Fpath.of_string entry in if R.is_error fp then false else not Fpath.(is_prefix threep (R.get_ok fp))) in
      prune_entries f >>= fun () ->
      (* 2. Add DKML_3P_PREFIX_PATH directories to front of INCLUDE,LIB,...,PKG_CONFIG_PATH and PATH *)
      Logs.debug (fun m -> m "third-party prefix directory = %a" Fpath.pp threep);
      prepend_entries ~tools:false threep
      >>= fun () -> helper rst
  in
  let dirs = String.cuts ~empty:false ~sep:";" (OS.Env.opt_var ~absent:"" "DKML_3P_PREFIX_PATH") in
  helper (List.rev dirs) >>| fun () ->
  (String.concat ~sep:";" dirs) :: cache_keys

(* [set_3p_program_entries cache_keys] will modify the PATH so that each directory in
   the semicolon separated environment variable DKML_3P_PROGRAM_PATH is present the PATH.
 *)
let set_3p_program_entries cache_keys =
  Lazy.force probe_os_path_sep >>= fun os_path_sep ->
  let rec helper = function
  | [] -> R.ok ()
  | dir :: rst ->
    let null_possible_dir = R.ignore_error ~use:(fun _e -> OS.File.null) (Fpath.of_string dir) in
    if (Fpath.compare OS.File.null null_possible_dir = 0) then
      (* skip over user-submitted directory because it has some parse error *)
      helper rst
    else
      let threep = null_possible_dir in
      let f = (fun entry -> let fp = Fpath.of_string entry in if R.is_error fp then false else not Fpath.(equal threep (R.get_ok fp))) in
      prune_envvar ~f ~path_sep:os_path_sep "PATH" >>= fun () ->
      OS.Env.parse "PATH" OS.Env.(some string) ~absent:None
      >>= prepend_envvar ~path_sep:os_path_sep "PATH" (Fpath.to_string threep)
  in
  let dirs = String.cuts ~empty:false ~sep:";" (OS.Env.opt_var ~absent:"" "DKML_3P_PROGRAM_PATH") in
  helper (List.rev dirs) >>| fun () ->
  (String.concat ~sep:";" dirs) :: cache_keys

(* [set_vcpkg_entries cache_keys] will modify MSVC/GCC/clang variables and PKG_CONFIG_PATH and PATH if
   vcpkg can be detected through [get_vcpkg_installed_dir].

  The CPATH, COMPILER_PATH, INCLUDE, LIBRARY_PATH, and LIB variables are modified so that
  if:

  - MSVC is used, INCLUDE and LIB are recognized
  - GCC is used, COMPILER_PATH and LIBRARY_PATH are recognized
    (https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables)
  - clang is used, CPATH and LIBRARY_PATH are are recognized
    ( https://clang.llvm.org/docs/CommandGuide/clang.html and https://reviews.llvm.org/D65880)
 *)
let set_vcpkg_entries cache_keys =
  (* 1. Remove vcpkg entries, if any, from compiler variables and PKG_CONFIG_PATH.
      The gcc compiler variables COMPILER_PATH and LIBRARY_PATH are always colon-separated
      per https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables.
      This _might_ conflict with clang if clang were run on Windows (very very unlikely)
      because clang's CPATH is explicitly OS path separated; perhaps clang's LIBRARY_PATH is as
      well.
  *)
  let dir_sep = Fpath.dir_sep in
  let f = (fun entry ->
    let contains = path_contains entry in
    not
      (contains (dir_sep ^ "vcpkg_installed" ^ dir_sep)
      || contains (dir_sep ^ "vcpkg" ^ dir_sep)
         && contains (dir_sep ^ "installed" ^ dir_sep))) in
  prune_entries f >>= fun () ->
  (* 2. Add vcpkg to front of INCLUDE,LIB,...,PKG_CONFIG_PATH and PATH, if vcpkg is available.
     For PATH, add:
     * <vcpkg>/bin
     * <vcpkg>/tools/pkgconf and whatever other tools exist
  *)
  Lazy.force get_vcpkg_installed_dir_opt >>= function
  | None ->
      Logs.debug (fun m -> m "No vcpkg installed directory");
      R.ok ("" :: cache_keys)
  | Some vcpkg_installed_dir ->
      let vcpkg_installed = Fpath.to_string vcpkg_installed_dir in
      Logs.debug (fun m -> m "vcpkg installed directory = %s" vcpkg_installed);
      prepend_entries ~tools:true vcpkg_installed_dir
      >>| fun () -> vcpkg_installed :: cache_keys

let main_with_result () =
  (* Setup logging *)
  Fmt_tty.setup_std_outputs ();
  Logs.set_reporter (Logs_fmt.reporter ());
  let dbt = OS.Env.value "DKML_BUILD_TRACE" OS.Env.string ~absent:"OFF" in
  if
    dbt = "ON"
    && OS.Env.value "DKML_BUILD_TRACE_LEVEL" int_parser ~absent:0 >= 2
  then Logs.set_level (Some Logs.Debug)
  else if dbt = "ON" then Logs.set_level (Some Logs.Info)
  else Logs.set_level (Some Logs.Warning);

  (* Create a command line with `...\usr\bin\env.exe CMD [ARGS...]`.
     We use env.exe because it has logic to check if CMD is a shell
     script and run it accordingly (MSYS2 always uses bash for some reason, instead
     of looking at shebang).
  *)
  Fpath.of_string "/" >>= fun slash ->
  (Lazy.force get_msys2_dir_opt >>= function
   | None -> R.ok Fpath.(slash / "usr" / "bin" / "env")
   | Some msys2_dir ->
       Logs.debug (fun m -> m "MSYS2 directory: %a" Fpath.pp msys2_dir);
       R.ok Fpath.(msys2_dir / "usr" / "bin" / "env.exe"))
  >>= fun env_exe ->
  let cmd_and_args = List.tl (Array.to_list Sys.argv) in
  (if [] = cmd_and_args then
   R.error_msgf "You need to supply a command, like `%s bash`" OS.Arg.exec
  else R.ok ())
  >>= fun () ->
  let cmd = Cmd.of_list ([ Fpath.to_string env_exe ] @ cmd_and_args) in

  Lazy.force get_dkmlversion >>= fun dkmlversion ->
  Lazy.force Target_context.V1.get_platform_name >>= fun target_platform_name ->
  let cache_keys = [ dkmlversion ] in
  (* FIRST, set DKML_TARGET_ABI, which may be overridden by DKML_TARGET_PLATFORM_OVERRIDE *)
  let target_platform_name = OS.Env.opt_var "DKML_TARGET_PLATFORM_OVERRIDE" ~absent:target_platform_name in
  OS.Env.set_var "DKML_TARGET_ABI" (Some target_platform_name) >>= fun () ->
  let cache_keys = target_platform_name :: cache_keys in
  (* SECOND, set MSYS2 environment variables.
     - This is needed before is_msys2_msys_build_machine() is called from crossplatform-functions.sh
       in add_microsoft_visual_studio_entries.
     - This also needs to happen before add_microsoft_visual_studio_entries so that MSVC `link.exe`
       can be inserted by VsDevCmd.bat before any MSYS2 `link.exe`. (`link.exe` is one example of many
       possible conflicts).
  *)
  set_msys2_entries target_platform_name >>= fun () ->
  (* THIRD, set MSVC entries *)
  set_msvc_entries cache_keys >>= fun cache_keys ->
  (* FOURTH, set vcpkg entries.
     - Since MSVC overwrites INCLUDE and LIB entirely, we have to do vcpkg entries
       _after_ MSVC.
  *)
  set_vcpkg_entries cache_keys >>= fun cache_keys ->
  (* FIFTH, set third-party (3p) prefix entries.
     Since MSVC overwrites INCLUDE and LIB entirely, we have to do vcpkg entries
     _after_ MSVC. *)
  set_3p_prefix_entries cache_keys >>= fun cache_keys ->
  (* SIXTH, set third-party (3p) program entries. *)
  set_3p_program_entries cache_keys >>= fun _cache_keys ->
  (* SEVENTH, stop special variables from propagating. *)
  OS.Env.set_var "DKML_BUILD_TRACE" None >>= fun () ->
  OS.Env.set_var "DKML_BUILD_TRACE_LEVEL" None >>= fun () ->
  (* Diagnostics *)
  OS.Env.current () >>= fun current_env ->
  OS.Dir.current () >>= fun current_dir ->
  Logs.debug (fun m ->
      m "Environment:@\n%a" Astring.String.Map.dump_string_map current_env);
  Logs.debug (fun m -> m "Current directory: %a" Fpath.pp current_dir);
  (Lazy.force get_dkmlhome_dir_opt >>| function
   | None -> ()
   | Some dkmlhome_dir ->
       Logs.debug (fun m -> m "DKML home directory: %a" Fpath.pp dkmlhome_dir))
  >>= fun () ->
  Logs.info (fun m -> m "Running command: %a" Cmd.pp cmd);

  (* Run the command *)
  OS.Cmd.run_status cmd >>| function
  | `Exited status -> exit status
  | `Signaled signal ->
      (* https://stackoverflow.com/questions/1101957/are-there-any-standard-exit-status-codes-in-linux/1535733#1535733 *)
      exit (128 + signal)

let () =
  match main_with_result () with
  | Ok _ -> ()
  | Error msg ->
      Fmt.pf Fmt.stderr "FATAL: %a@\n" Rresult.R.pp_msg msg;
      exit 1
