open Bos
open Rresult
open Opam_context

(** [get_vcpkg_installed_dir_opt] is a lazy function that gets installed headers, binaries
    and libraries of vcpkg.

    Specification:

    * Some (<env:DKML_VCPKG_MANIFEST_DIR>/vcpkg_installed/<env:DKML_VCPKG_HOST_TRIPLET>) if both
      the DKML_ environment variables exist
    * Some (<OPAMROOT>/plugins/diskuvocaml/vcpkg/<dkmlversion>/installed/<env:DKML_VCPKG_HOST_TRIPLET>)
      if DKML_VCPKG_HOST_TRIPLET exists. <OPAMROOT> is either <env:OPAMROOT> or the implied
      Opam root (<env:LOCALAPPDATA>/opam)
    * None otherwise
  *)
let get_vcpkg_installed_dir_opt =
  lazy
    (let vcpkg_host_triplet =
       OS.Env.opt_var "DKML_VCPKG_HOST_TRIPLET" ~absent:""
     in
     OS.Env.parse "DKML_VCPKG_MANIFEST_DIR" OS.Env.path ~absent:OS.File.null
     >>= fun vcpkg_manifest_dir ->
     if "" <> vcpkg_host_triplet then
       if Fpath.compare OS.File.null vcpkg_manifest_dir = 0 then
         Lazy.force (get_dkml_product_plugin_dir "vcpkg") >>| fun vcpkg_dir ->
         Some Fpath.(vcpkg_dir / "installed" / vcpkg_host_triplet)
       else
         R.ok
           (Some
              Fpath.(
                vcpkg_manifest_dir / "vcpkg_installed" / vcpkg_host_triplet))
     else R.ok None)
