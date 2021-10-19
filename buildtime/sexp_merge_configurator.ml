(* sexp_merge_configurator SEXP_DIRECTORY SEXP_NAME DUNE_PROFILE

   A directory listing example of SEXP_DIRECTORY if SEXP_NAME were "ocamlopt_flags":

     1-base.ocamlopt_flags.sexp
     2-android_arm32v7a-all.ocamlopt_flags.sexp
     3-all-Release.ocamlopt_flags.sexp
     4-darwin_x86_64-Release.ocamlopt_flags.sexp

   Some examples of DUNE_PROFILE:
     dev-Debug
     linux_x86_64-Release

   First the DUNE_PROFILE is parsed into PLATFORM (ex. linux_x86_64) and BUILDTYPE (ex. Release).

   Then the output will be a single s-exp that is a concatenation of the following sexps in order:
     1-base.SEXP_NAME.sexp
     2-PLATFORM-all.SEXP_NAME.sexp
     3-all-BUILDTYPE.SEXP_NAME.sexp
     4-PLATFORM-BUILDTYPE.SEXP_NAME.sexp

   Each of those four (4) s-exps is enclosed in parentheses so that set subtraction is confined to
   its original intent. For example, if `1-base.SEXP_NAME.sexp` where "(:standard \ -g)" then you could get:

     ((:standard \ -g) (-ccopt -static) () ())

   but not the following which has a very different meaning:

     (:standard \ -g -ccopt -static)

   This relies on the semantics of https://dune.readthedocs.io/en/stable/concepts.html#ordered-set-language:

   > a list of sets is the concatenation of its inner sets
*)

let sexp_directory = Sys.argv.(1)

let sexp_name = Sys.argv.(2)

let dune_profile = Sys.argv.(3)

let profile_separator = '-'

let load_config prefix =
  let dos2unix = Str.global_replace (Str.regexp "\r\n") "\n" in
  let basename = String.concat "." [ prefix; sexp_name; "sexp" ] in
  let ic = open_in_bin (Filename.concat sexp_directory basename) in
  try
    (* Convert any CRLF into LF (0x0a) *)
    really_input_string ic (in_channel_length ic) |> dos2unix |> String.trim
  with e ->
    close_in_noerr ic;
    raise e

let merge_config (config_lst : string list) : string =
  (* Intermediate newlines are LF (0x0a) *)
  "(\n" ^ String.concat "\n" config_lst ^ "\n)"

let () =
  match String.split_on_char profile_separator dune_profile with
  | platform :: build_type_rst ->
      let build_type =
        String.concat (String.make 1 profile_separator) build_type_rst
      in
      let merged_config =
        merge_config
          [
            load_config "1-base";
            load_config (Format.asprintf "2-%s-all" platform);
            load_config (Format.asprintf "3-all-%s" build_type);
            load_config (Format.asprintf "4-%s-%s" platform build_type);
          ]
      in
      Format.fprintf Format.err_formatter
        "Profile: %s@\nPlatform is %s and build type is %s.@\n%s: %s@\n"
        dune_profile platform build_type sexp_name merged_config;
      (* Final newline is LF (0x0a) *)
      print_endline merged_config
  | _ -> failwith ""
