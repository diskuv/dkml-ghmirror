(*
To setup on Unix/macOS:
  eval $(opam env --switch diskuv-host-tools --set-switch)
  # or: eval $(opam env) && opam install dune bos logs fmt sexplib sha
  opam install ocaml-lsp-server ocamlformat ocamlformat-rpc # optional, for vscode or emacs

To setup on Windows:
  1. Make sure $DiskuvOCamlHome/share/dkml/functions/crossplatform-functions.sh exists.
  2. Run in MSYS2:
    eval $(opam env --switch "$DiskuvOCamlHome/host-tools" --set-switch)

To test:
    dune build installtime/msys2/apps/opam-dkml/opam_dkml.exe
    DKML_BUILD_TRACE=ON DKML_BUILD_TRACE_LEVEL=2 _build/default/installtime/msys2/apps/opam-dkml/opam_dkml.exe

To install and test:
    opam install ./installtime/msys2/apps/opam-dkml.opam
    DKML_BUILD_TRACE=ON DKML_BUILD_TRACE_LEVEL=2 opam dkml
*)
open Bos
open Rresult
open Dkml_apps_common
open Cmdliner

let setup () =
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

  (* Setup MSYS2 *)
  Lazy.force Target_context.V1.get_platform_name >>= fun target_platform_name ->
  Dkml_environment.set_msys2_entries target_platform_name >>= fun () ->

  (* Diagnostics *)
  OS.Env.current () >>= fun current_env ->
  OS.Dir.current () >>= fun current_dir ->
  Logs.debug (fun m ->
      m "Environment:@\n%a" Astring.String.Map.dump_string_map current_env);
  Logs.debug (fun m -> m "Current directory: %a" Fpath.pp current_dir);
  Lazy.force get_dkmlhome_dir_opt >>| function
  | None -> ()
  | Some dkmlhome_dir ->
      Logs.debug (fun m -> m "DKML home directory: %a" Fpath.pp dkmlhome_dir)

let rresult_to_term_result = function
  | Ok _ -> `Ok ()
  | Error msg -> `Error (false, Fmt.str "FATAL: %a@\n" Rresult.R.pp_msg msg)

let yes_t =
  let doc = "Answer yes to all interactive yes/no questions" in
  Arg.(value & flag & info [ "y"; "yes" ] ~doc)

let localdir_opt_t =
  let doc =
    "Use the specified local directory rather than the current directory"
  in
  let docv = "LOCALDIR" in
  let conv_fp c =
    let parser v = Arg.conv_parser c v >>= Fpath.of_string in
    let printer v = Fpath.pp v in
    Arg.conv ~docv (parser, printer)
  in
  Arg.(value & opt (some (conv_fp dir)) None & info [ "d"; "dir" ] ~doc ~docv)

let init_t =
  Term.ret
  @@ Term.(
       const rresult_to_term_result
       $ (const Cmd_init.run $ const setup $ localdir_opt_t $ Cmd_init.buildtype_t $ yes_t))

let main_t = Term.(ret @@ const (`Help (`Auto, None)))

let () =
  Term.exit
  @@ Term.eval_choice
       (main_t, Term.info "opam dkml")
       [
         ( init_t,
           Term.info
             ~doc:
               "Creates or updates an `_opam` subdirectory from zero or more \
                `*.opam` files in the local directory"
             ~man:
               ([
                 `P
                   "The `_opam` directory, also known as the local Opam \
                    switch, holds an OCaml compiler and all of the packages \
                    that are specified in the `*.opam` files.";
                 `P
                   "$(b,--build-type=Release) uses the flamba optimizer \
                    described at https://ocaml.org/manual/flambda.html";
               ] @ if Sys.win32 then [] else [
                 `P
                   "$(b,--build-type=ReleaseCompatPerf) has compatibility \
                    with 'perf' monitoring tool. Compatible with Linux only.";
                 `P
                   "$(b,--build-type=ReleaseCompatFuzz) has compatibility \
                    with 'afl' fuzzing tool. Compatible with Linux only.";
               ])
             "init" );
       ]
