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

let usage_msg = "dkml_opam_build.exe CMD [ARGS...]\n"

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

let prune_path path =
  String.cuts ~empty:false ~sep:";" path
  |> List.filter (fun entry ->
         let contains s =
           String.find_sub ~sub:(String.Ascii.lowercase s)
             (String.Ascii.lowercase entry)
           |> Option.is_some
         in
         let ends_with s =
           String.is_suffix ~affix:(String.Ascii.lowercase s)
             (String.Ascii.lowercase entry)
         in
         not
           (ends_with "\\Common7\\IDE"
           || ends_with "\\Common7\\Tools"
           || ends_with "\\MSBuild\\Current\\Bin"
           || contains "\\VC\\Tools\\MSVC\\"
           || contains "\\Windows Kits\\10\\bin\\"
           || contains "\\Microsoft.NET\\Framework64\\"
           || contains "\\MSBuild\\Current\\bin\\"))

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
  OS.Env.(
    (* 3. Remove MSVC entries from PATH *)
    req_var "PATH" >>= fun path ->
    set_var "PATH" (Some (String.concat ~sep:";" (prune_path path))))

(* Mimics set_dkmlparenthomedir *)
let get_dkmlparenthomedir () =
  let open OS.Env in
  match req_var "LOCALAPPDATA" with
  | Ok localappdata ->
      Fpath.of_string localappdata >>| fun fp ->
      Fpath.(fp / "Programs" / "DiskuvOCaml")
  | Error _ -> (
      match req_var "XDG_DATA_HOME" with
      | Ok xdg_data_home ->
          Fpath.of_string xdg_data_home >>| fun fp ->
          Fpath.(fp / "diskuv-ocaml")
      | Error _ -> (
          match req_var "HOME" with
          | Ok home ->
              Fpath.of_string home >>| fun fp ->
              Fpath.(fp / ".local" / "share" / "diskuv-ocaml")
          | Error _ as err -> err))

let association_list_of_sexp =
  Conv.list_of_sexp (Conv.pair_of_sexp Conv.string_of_sexp Conv.string_of_sexp)

(* [get_dkmlvars ()] gets an association list of dkmlvars.sexp *)
let get_dkmlvars () =
  get_dkmlparenthomedir () >>| fun fp ->
  Sexp.load_sexp_conv_exn
    Fpath.(fp / "dkmlvars.sexp" |> to_string)
    association_list_of_sexp

(* Get MSYS2 directory *)
let get_msys2_dir () =
  get_dkmlvars () >>= fun assocl ->
  match List.assoc_opt "DiskuvOCamlMSYS2Dir" assocl with
  | Some v -> Fpath.of_string v >>= fun fp -> Rresult.R.ok fp
  | None -> Rresult.R.error_msg "No DiskuvOCamlMSYS2Dir in dkmlvars.sexp"

(* Get Diskuv OCaml home directory *)
let get_dkmlhome_dir () =
  get_dkmlvars () >>= fun assocl ->
  match List.assoc_opt "DiskuvOCamlHome" assocl with
  | Some v -> Fpath.of_string v >>= fun fp -> Rresult.R.ok fp
  | None -> Rresult.R.error_msg "No DiskuvOCamlHome in dkmlvars.sexp"

(* Get Diskuv OCaml deployment id, which can be used as part of a cache key *)
let get_dkmldeployment_id () =
  get_dkmlvars () >>= fun assocl ->
  match List.assoc_opt "DiskuvOCamlDeploymentId" assocl with
  | Some v -> Rresult.R.ok v
  | None -> Rresult.R.error_msg "No DiskuvOCamlDeploymentId in dkmlvars.sexp"

(* [add_microsoft_visual_studio_entries path] updates the environment to include
   Microsoft Visual Studio entries like LIB, INCLUDE and the others listed in
   [msvc_as_is_vars]. Additionally PATH is updated.

   The input [path] is used as a cache key.
*)
let add_microsoft_visual_studio_entries dkmlhome_dir msys2_dir dkmldeployment_id
    =
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
  OS.Env.parse "OPAM_SWITCH_PREFIX" OS.Env.path ~absent:OS.File.null
  >>= fun opam_switch_prefix ->
  if Fpath.compare OS.File.null opam_switch_prefix = 0 then
    Rresult.R.error_msgf "OPAM_SWITCH_PREFIX is not an environment variable"
  else
    Rresult.R.ok opam_switch_prefix >>= fun opam_switch_prefix ->
    let cache_dir = Fpath.(opam_switch_prefix / ".dkml" / "compiler-cache") in
    let cache_key =
      (* The cache is made of the deployment id (basically the version of DKML) and the input path *)
      let ctx = Sha256.init () in
      Sha256.update_string ctx dkmldeployment_id;
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
      Ok ())
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
        (* Store the as-is and PATH compiler environment variables in an association list *)
        let setvars =
          List.filter_map
            (fun varname ->
              match List.assoc_opt varname env_vars with
              | Some varvalue ->
                  Some Sexp.(List [ Atom varname; Atom varvalue ])
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

let set_msys2_entries () =
  OS.Env.set_var "MSYSTEM" (Some "MSYS")

let int_parser = OS.Env.(parser "int" String.to_int)

let main_with_result () =
  (* Setup logging *)
  Fmt_tty.setup_std_outputs ();
  Logs.set_reporter (Logs_fmt.reporter ());
  let dbt = OS.Env.value "DKML_BUILD_TRACE" OS.Env.string ~absent:"OFF" in
  if dbt = "ON" && OS.Env.value "DKML_BUILD_TRACE_LEVEL" int_parser ~absent:0 >= 2
  then Logs.set_level (Some Logs.Debug)
  else if dbt = "ON"
  then Logs.set_level (Some Logs.Info)
  else Logs.set_level (Some Logs.Warning);

  (* Create a command line with `...\usr\bin\env.exe CMD [ARGS...]`.
     We use env.exe because it has logic to check if CMD is a shell
     script and run it accordingly (MSYS2 always uses bash for some reason, instead
     of looking at shebang).
   *)
  get_msys2_dir () >>= fun msys2_dir ->
  let env_exe = Fpath.(msys2_dir / "usr" / "bin" / "env.exe") in
  let cmd_and_args = List.tl (Array.to_list Sys.argv) in
  let cmd = Cmd.of_list ([Fpath.to_string env_exe] @ cmd_and_args) in

  (* Set MSYS2 environment variables.
     - This is needed before is_msys2_msys_build_machine() is called from crossplatform-functions.sh
       in add_microsoft_visual_studio_entries.
   *)
  set_msys2_entries () >>= fun () ->
  (* Remove MSVC environment variables *)
  remove_microsoft_visual_studio_entries () >>= fun () ->
  (* Add MSVC entries *)
  get_dkmlhome_dir () >>= fun dkmlhome_dir ->
  get_dkmldeployment_id () >>= fun dkmldeployment_id ->
  add_microsoft_visual_studio_entries dkmlhome_dir msys2_dir dkmldeployment_id
  >>= fun () ->
  (* Diagnostics *)
  OS.Env.current () >>= fun current_env ->
  OS.Dir.current () >>= fun current_dir ->
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
