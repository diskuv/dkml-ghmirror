open Bos
open Astring
include Dkml_context
include Dkml_root
module Dkml_scripts = Scripts
module Target_context = Target_context
module Dkml_environment = Dkml_environment

module Monadic_operators = struct
  (* Result monad operators *)
  let ( >>= ) = Result.bind

  let ( >>| ) = Result.map
end

let int_parser = OS.Env.(parser "int" String.to_int)

let extract_dkml_scripts dir_fp =
  let open Monadic_operators in
  List.fold_left
    (fun acc filename ->
      match acc with
      | Ok _ ->
          (* mkdir (parent filename) *)
          Fpath.of_string filename >>= fun filename_fp ->
          let target_fp = Fpath.(dir_fp // filename_fp) in
          let target_dir_fp = Fpath.(parent target_fp) in
          OS.Dir.create target_dir_fp |> ignore;
          (* cp script filename *)
          let script_opt = Dkml_scripts.read filename in
          Option.fold ~none:(Result.Ok ())
            ~some:(fun script -> OS.File.write target_fp script)
            script_opt
      | Error _ as err -> err)
    (Result.Ok ()) Dkml_scripts.file_list
  >>= fun () ->
  (* cp <builtin> .dkmlroot *)
  OS.File.write Fpath.(dir_fp // v ".dkmlroot") dkmlroot_contents
