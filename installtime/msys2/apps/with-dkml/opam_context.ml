open Bos
open Rresult
open Dkml_apps_common

let fpath_notnull f = Fpath.compare OS.File.null f <> 0

(** [get_opam_root] is a lazy function that gets the OPAMROOT environment variable.
    If OPAMROOT is not found, then <LOCALAPPDATA>/opam is used for Windows
    and $XDG_CONFIG_HOME/opam with fallback to ~/.config/opam for Unix instead.

    Conforms to https://github.com/ocaml/opam/pull/4815#issuecomment-910137754.
  *)
  let get_opam_root =
  lazy
  ( OS.Env.parse "LOCALAPPDATA" OS.Env.path ~absent:OS.File.null
  >>= fun localappdata ->
    OS.Env.parse "XDG_CONFIG_HOME" OS.Env.path ~absent:OS.File.null
    >>= fun xdgconfighome ->
    OS.Env.parse "HOME" OS.Env.path ~absent:OS.File.null >>= fun home ->
    OS.Env.parse "OPAMROOT" OS.Env.path ~absent:OS.File.null >>= fun opamroot ->
    match fpath_notnull opamroot, fpath_notnull localappdata, fpath_notnull xdgconfighome, fpath_notnull home with
    | true, _, _, _ -> R.ok opamroot
    | false, true, _, _ -> R.ok Fpath.(localappdata / "opam")
    | false, false, true, _ -> R.ok Fpath.(xdgconfighome / "opam")
    | false, false, false, true -> R.ok Fpath.(home / ".config" / "opam")
    | false, false, false, false -> R.error_msg "Unable to locate Opam root because none of LOCALAPPDATA, XDG_CONFIG_HOME, HOME or OPAMROOT was set"
  )

(** [get_opam_switch_prefix] is a lazy function that gets the OPAM_SWITCH_PREFIX environment variable.
    If OPAM_SWITCH_PREFIX is not found, then the Opam switch <dkmlhome_dir>/host-tools (defined on Windows DKML)
    with a fallback to <OPAMROOT>/default is used instead. *)
let get_opam_switch_prefix =
  lazy
  ( Lazy.force get_dkmlhome_dir_opt >>= fun dkmlhome_dir_opt ->
    Lazy.force get_opam_root >>= fun opamroot ->
    OS.Env.parse "OPAM_SWITCH_PREFIX" OS.Env.path ~absent:OS.File.null >>| fun opamswitchprefix ->
    match fpath_notnull opamswitchprefix, dkmlhome_dir_opt with
    | true, _ -> opamswitchprefix
    | false, Some dkmlhome_dir -> Fpath.(dkmlhome_dir / "system")
    | false, None -> Fpath.(opamroot / "default"))


(** [get_dkml_product_plugin_dir product] is a lazy function to get the DKML plugin product directory. A product
    may be one of: [vcpkg].
    The DKML plugins are located in OPAMROOT/plugins/diskuvocaml/PRODUCT/<dkmlversion>.
  *)
let get_dkml_product_plugin_dir product =
  lazy
    ( Lazy.force get_opam_root >>= fun opam_root ->
      Lazy.force get_dkmlversion >>| fun dkmlversion ->
      Fpath.(opam_root / "plugins" / "diskuvocaml" / product / dkmlversion) )
