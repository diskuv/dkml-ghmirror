open Bos
open Rresult
open Sexplib

let association_list_of_sexp =
  Conv.list_of_sexp (Conv.pair_of_sexp Conv.string_of_sexp Conv.string_of_sexp)

(* Mimics set_dkmlparenthomedir *)
let get_dkmlparenthomedir =
  lazy
    (let open OS.Env in
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
            | Error _ as err -> err)))

(* [get_dkmlvars ()] gets an association list of dkmlvars.sexp *)
let get_dkmlvars =
  lazy
    ( Lazy.force get_dkmlparenthomedir >>| fun fp ->
      Sexp.load_sexp_conv_exn
        Fpath.(fp / "dkmlvars.sexp" |> to_string)
        association_list_of_sexp )

(* Get DKML version *)
let get_dkmlversion =
  lazy
    ( Lazy.force get_dkmlvars >>= fun assocl ->
      match List.assoc_opt "DiskuvOCamlVersion" assocl with
      | Some v -> Rresult.R.ok v
      | None -> Rresult.R.error_msg "No DiskuvOCamlVersion in dkmlvars.sexp" )

(* Get MSYS2 directory *)
let get_msys2_dir =
  lazy
    ( Lazy.force get_dkmlvars >>= fun assocl ->
      match List.assoc_opt "DiskuvOCamlMSYS2Dir" assocl with
      | Some v -> Fpath.of_string v >>= fun fp -> Rresult.R.ok fp
      | None -> Rresult.R.error_msg "No DiskuvOCamlMSYS2Dir in dkmlvars.sexp" )

(* Get Diskuv OCaml home directory *)
let get_dkmlhome_dir =
  lazy
    ( Lazy.force get_dkmlvars >>= fun assocl ->
      match List.assoc_opt "DiskuvOCamlHome" assocl with
      | Some v -> Fpath.of_string v >>= fun fp -> Rresult.R.ok fp
      | None -> Rresult.R.error_msg "No DiskuvOCamlHome in dkmlvars.sexp" )

(* Get Diskuv OCaml deployment id, which can be used as part of a cache key *)
let get_dkmldeployment_id =
  lazy
    ( Lazy.force get_dkmlvars >>= fun assocl ->
      match List.assoc_opt "DiskuvOCamlDeploymentId" assocl with
      | Some v -> Rresult.R.ok v
      | None ->
          Rresult.R.error_msg "No DiskuvOCamlDeploymentId in dkmlvars.sexp" )
