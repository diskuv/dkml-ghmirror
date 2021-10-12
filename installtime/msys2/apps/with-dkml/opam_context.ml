open Bos
open Rresult
open Dkml_context

(** [get_opam_root] is a lazy function that gets the OPAMROOT environment variable.
    If OPAMROOT is not found, then <LOCALAPPDATA>/opam is used instead. *)
let get_opam_root =
  lazy
    ( OS.Env.req_var "LOCALAPPDATA" >>= fun localappdata_s ->
      Fpath.of_string localappdata_s >>= fun localappdata ->
      OS.Env.parse "OPAMROOT" OS.Env.path ~absent:Fpath.(localappdata / "opam")
    )

(** [get_opam_switch_prefix] is a lazy function that gets the OPAM_SWITCH_PREFIX environment variable.
    If OPAM_SWITCH_PREFIX is not found, then the <dkmlhome_dir>/system Opam switch is used instead. *)
let get_opam_switch_prefix =
  lazy
    ( Lazy.force get_dkmlhome_dir >>= fun dkmlhome_dir ->
      OS.Env.parse "OPAM_SWITCH_PREFIX" OS.Env.path
        ~absent:Fpath.(dkmlhome_dir / "system") )

(** [get_dkml_product_plugin_dir product] is a lazy function to get the DKML plugin product directory. A product
    may be one of: [vcpkg].
    The DKML plugins are located in OPAMROOT/plugins/diskuvocaml/PRODUCT/<dkmlversion>.
  *)
let get_dkml_product_plugin_dir product =
  lazy
    ( Lazy.force get_opam_root >>= fun opam_root ->
      Lazy.force get_dkmlversion >>| fun dkmlversion ->
      Fpath.(opam_root / "plugins" / "diskuvocaml" / product / dkmlversion) )
