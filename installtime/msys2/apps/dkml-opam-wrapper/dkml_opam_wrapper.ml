(*
To test on Windows:
  1. Make sure $DiskuvOCamlHome/share/dkml/functions/crossplatform-functions.sh exists.
  2. Run in MSYS2:
    eval $(opam env --switch "$DiskuvOCamlHome/system" --set-switch)
    dune build --root installtime/msys2/apps/ dkml-opam-wrapper/dkml_opam_wrapper.exe
    DKML_BUILD_TRACE=ON DKML_BUILD_TRACE_LEVEL=2 ./installtime/msys2/apps/_build/default/dkml-opam-wrapper/dkml_opam_wrapper.exe sleep 5
*)
open Bos
open Rresult
open Astring
open Sexplib
open Dkml_context
open Opam_context
open Vcpkg_context

let usage_msg = "dkml-opam-build.exe CMD [ARGS...]\n"

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

let contains entry s =
  String.find_sub ~sub:(String.Ascii.lowercase s) (String.Ascii.lowercase entry)
  |> Option.is_some

let ends_with entry s =
  String.is_suffix ~affix:(String.Ascii.lowercase s)
    (String.Ascii.lowercase entry)

(** [prune_path_of_microsoft_visual_studio ()] removes all Microsoft Visual Studio entries from the environment
    variable PATH *)
let prune_path_of_microsoft_visual_studio () =
  OS.Env.req_var "PATH" >>= fun path ->
  String.cuts ~empty:false ~sep:";" path
  |> List.filter (fun entry ->
         let contains = contains entry in
         let ends_with = ends_with entry in
         not
           (ends_with "\\Common7\\IDE"
           || ends_with "\\Common7\\Tools"
           || ends_with "\\MSBuild\\Current\\Bin"
           || contains "\\VC\\Tools\\MSVC\\"
           || contains "\\Windows Kits\\10\\bin\\"
           || contains "\\Microsoft.NET\\Framework64\\"
           || contains "\\MSBuild\\Current\\bin\\"))
  |> fun paths -> Some (String.concat ~sep:";" paths) |> OS.Env.set_var "PATH"

(** prune_path_of_msys2 ()] removes .../MSYS2/usr/bin from the PATH environment variable *)
let prune_path_of_msys2 () =
  OS.Env.req_var "PATH" >>= fun path ->
  String.cuts ~empty:false ~sep:";" path
  |> List.filter (fun entry ->
         let ends_with = ends_with entry in
         not (ends_with "\\MSYS2\\usr\\bin"))
  |> fun paths -> Some (String.concat ~sep:";" paths) |> OS.Env.set_var "PATH"

let prune_envvar_of_vcpkg varname =
  let varvalue = OS.Env.opt_var varname ~absent:"" in
  if "" = varvalue then R.ok ()
  else
    String.cuts ~empty:false ~sep:";" varvalue
    |> List.filter (fun entry ->
           let contains = contains entry in
           not
             (contains "\\vcpkg_installed\\"
             || (contains "\\vcpkg\\" && contains "\\installed\\")))
    |> fun entries ->
    Some (String.concat ~sep:";" entries) |> OS.Env.set_var varname

(** Remove every MSVC environment variable from the environment and prune MSVC
    entries from the PATH environment variable. *)
let remove_microsoft_visual_studio_entries () =
  (* 1. Remove all as-is variables *)
  List.fold_right
    (fun varname acc ->
      match acc with Ok () -> OS.Env.set_var varname None | Error _ -> acc)
    msvc_as_is_vars (Ok ())
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
   [msvc_as_is_vars]. Additionally PATH is updated.

   The PATH environment variable on entry is used as a cache key.

   If OPAM_SWITCH_PREFIX is not defined, then <dkmlhome_dir>/system (the Diskuv
   System opam switch) is used instead.
*)
let set_msvc_entries cache_keys =
  (* 1. Remove MSVC entries *)
  remove_microsoft_visual_studio_entries () >>= fun () ->
  (* 2. Add MSVC entries *)
  Lazy.force get_msys2_dir >>= fun msys2_dir ->
  Lazy.force get_dkmlhome_dir >>= fun dkmlhome_dir ->
  let do_set setvars =
    List.iter
      (fun (varname, varvalue) ->
        OS.Env.set_var varname (Some varvalue)
        |> Rresult.R.error_msg_to_invalid_arg;
        Logs.debug (fun m ->
            m "Setting (name,value) = (%s,%s)" varname varvalue))
      (association_list_of_sexp setvars)
  in
  OS.Env.req_var "PATH" >>= fun path ->
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
    Logs.info (fun m -> m "Loading compiler cache entry %a" Fpath.pp cache_file);

    let setvars = Sexp.load_sexp (Fpath.to_string cache_file) in
    do_set setvars;
    Ok ())
  else
    (* Cache miss *)
    let cache_miss tmp_sexp_file _oc _v =
      let dash = Fpath.(msys2_dir / "usr" / "bin" / "dash.exe" |> to_string) in

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
      (* Store the as-is and PATH compiler environment variables in an association list *)
      let setvars =
        List.filter_map
          (fun varname ->
            match List.assoc_opt varname env_vars with
            | Some varvalue -> Some Sexp.(List [ Atom varname; Atom varvalue ])
            | None -> None)
          ("PATH" :: msvc_as_is_vars)
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
        Ok ()
    | Ok (Error _ as err) -> err
    | Error _ as err -> err

(** Set the MSYSTEM environment variable to MSYS and place MSYS2 binaries at the front of the PATH.
    Any existing MSYS2 binaries in the PATH will be removed.
  *)
let set_msys2_entries () =
  Lazy.force get_msys2_dir >>= fun msys2_dir ->
  (* 1. MSYSTEM = MSYS *)
  OS.Env.set_var "MSYSTEM" (Some "MSYS") >>= fun () ->
  (* 2. Remove MSYS2 entries, if any, from PATH *)
  prune_path_of_msys2 () >>= fun () ->
  (* 3. Add MSYS2 back to front of PATH *)
  OS.Env.req_var "PATH" >>= fun path ->
  OS.Env.set_var "PATH"
    (Some (Fpath.(msys2_dir / "usr" / "bin" |> to_string) ^ ";" ^ path))

(* [set_vcpkg_entries cache_keys] will modify INCLUDE and LIB and PKG_CONFIG_PATH and PATH if
   vcpkg can be detected through [get_vcpkg_installed_dir]. *)
let set_vcpkg_entries cache_keys =
  (* 1. Remove vcpkg entries, if any, from INCLUDE and LIB and PKG_CONFIG_PATH *)
  prune_envvar_of_vcpkg "INCLUDE" >>= fun () ->
  prune_envvar_of_vcpkg "LIB" >>= fun () ->
  prune_envvar_of_vcpkg "PKG_CONFIG_PATH" >>= fun () ->
  prune_envvar_of_vcpkg "PATH" >>= fun () ->
  (* 2. Add vcpkg to front of INCLUDE and LIB and PKG_CONFIG_PATH and PATH, if vcpkg is available.
        For PATH, add:
        * <vcpkg>/bin
        * <vcpkg>/tools/pkgconf
  *)
  Lazy.force get_vcpkg_installed_dir >>= function
  | None ->
      Logs.debug (fun m -> m "No vcpkg installed directory");
      R.ok ("" :: cache_keys)
  | Some vcpkg_installed_dir ->
      let vcpkg_installed = Fpath.to_string vcpkg_installed_dir in
      Logs.debug (fun m -> m "vcpkg installed directory = %s" vcpkg_installed);
      let setenvvar varname dir = function
        | None -> OS.Env.set_var varname (Some dir)
        | Some v -> OS.Env.set_var varname (Some (dir ^ ";" ^ v))
      in
      OS.Env.parse "INCLUDE" OS.Env.(some string) ~absent:None
      >>= setenvvar "INCLUDE"
            Fpath.(vcpkg_installed_dir / "include" |> to_string)
      >>= fun () ->
      OS.Env.parse "LIB" OS.Env.(some string) ~absent:None
      >>= setenvvar "LIB" Fpath.(vcpkg_installed_dir / "lib" |> to_string)
      >>= fun () ->
      OS.Env.parse "PKG_CONFIG_PATH" OS.Env.(some string) ~absent:None
      >>= setenvvar "PKG_CONFIG_PATH"
            Fpath.(vcpkg_installed_dir / "lib" / "pkgconfig" |> to_string)
      >>= fun () ->
      let vcpkg_installed_path =
        Fpath.(vcpkg_installed_dir / "bin" |> to_string)
        ^ ";"
        ^ Fpath.(vcpkg_installed_dir / "tools" / "pkgconf" |> to_string)
      in
      OS.Env.parse "PATH" OS.Env.(some string) ~absent:None
      >>= setenvvar "PATH" vcpkg_installed_path
      >>| fun () -> vcpkg_installed :: cache_keys

let int_parser = OS.Env.(parser "int" String.to_int)

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
  Lazy.force get_msys2_dir >>= fun msys2_dir ->
  let env_exe = Fpath.(msys2_dir / "usr" / "bin" / "env.exe") in
  let cmd_and_args = List.tl (Array.to_list Sys.argv) in
  let cmd = Cmd.of_list ([ Fpath.to_string env_exe ] @ cmd_and_args) in

  Lazy.force get_dkmldeployment_id >>= fun dkmldeployment_id ->
  let cache_keys = [ dkmldeployment_id ] in
  (* FIRST, set MSYS2 environment variables.
     - This is needed before is_msys2_msys_build_machine() is called from crossplatform-functions.sh
       in add_microsoft_visual_studio_entries.
     - This also needs to happen before add_microsoft_visual_studio_entries so that MSVC `link.exe`
       can be inserted by VsDevCmd.bat before any MSYS2 `link.exe`. (`link.exe` is one example of many
       possible conflicts).
  *)
  set_msys2_entries () >>= fun () ->
  (* SECOND, set MSVC entries *)
  set_msvc_entries cache_keys >>= fun () ->
  (* THIRD, set vcpkg entries.
     - Since MSVC overwrites INCLUDE and LIB entirely, we have to do vcpkg entries
       _after_ MSVC.
  *)
  set_vcpkg_entries cache_keys >>= fun _cache_keys ->
  (* Diagnostics *)
  OS.Env.current () >>= fun current_env ->
  OS.Dir.current () >>= fun current_dir ->
  Lazy.force get_dkmlhome_dir >>= fun dkmlhome_dir ->
  Logs.debug (fun m ->
      m "Environment:@\n%a" Astring.String.Map.dump_string_map current_env);
  Logs.debug (fun m -> m "Current directory: %a" Fpath.pp current_dir);
  Logs.debug (fun m -> m "DKML home directory: %a" Fpath.pp dkmlhome_dir);
  Logs.debug (fun m -> m "MSYS2 directory: %a" Fpath.pp msys2_dir);
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
