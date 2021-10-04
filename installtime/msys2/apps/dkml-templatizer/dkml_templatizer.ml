open Bos
open Jingoo

let usage_msg =
  "dkml_templatizer.exe [-o OUTPUT_FILE] TEMPLATE_FILE\n\n\
   Requirements: DiskuvOCamlHome environment value must be defined.\n"

let path_ref = ref ""

let quiet_ref = ref false
let output_file_ref = ref ""

let anon_fun path = path_ref := path

let speclist =
  [
    ( "-q", Arg.Set quiet_ref,
      "Quiet mode. Does not print messages to standard error unless there is an error");
    ( "-o",
      Arg.Set_string output_file_ref,
      "Save the resulting file to OUTPUT_FILE. Defaults to standard output" );
  ]

let () =
  Arg.parse speclist anon_fun usage_msg;
  if !path_ref = "" then (
    prerr_endline usage_msg;
    prerr_endline "FATAL: Missing TEMPLATE_FILE";
    exit 1);
  let dkml_home = Sys.getenv "DiskuvOCamlHome" in
  if not !quiet_ref then prerr_endline ("dkml_home = " ^ dkml_home);
  if not !quiet_ref then prerr_endline ("PATH = " ^ (Sys.getenv "PATH"));
  let cygpath = Cmd.v "cygpath" in
  let dkml_home_windows =
    let cmd = Cmd.(cygpath % "-aw" % dkml_home) in
    Result.get_ok OS.Cmd.(run_out cmd |> to_string ~trim:true)
  in
  let dkml_home_mixed =
    let cmd = Cmd.(cygpath % "-am" % dkml_home) in
    Result.get_ok OS.Cmd.(run_out cmd |> to_string ~trim:true)
  in
  let dkml_home_unix =
    let cmd = Cmd.(cygpath % "-au" % dkml_home) in
    Result.get_ok OS.Cmd.(run_out cmd |> to_string ~trim:true)
  in
  let models =
    [
      ("DiskuvOCamlHome_Windows", Jg_types.Tstr dkml_home_windows);
      ("DiskuvOCamlHome_Unix", Jg_types.Tstr dkml_home_unix);
      ("DiskuvOCamlHome_Mixed", Jg_types.Tstr dkml_home_mixed);
    ]
  in
  let result = Jg_template.from_file !path_ref ~models in
  if !output_file_ref = "" then print_endline result
  else
    let oc = open_out !output_file_ref in
    output_string oc result;
    close_out oc
