open Bos
open Rresult
open Dkml_context

let get_opam_switch_prefix =
  lazy
    ( Lazy.force get_dkmlhome_dir >>= fun dkmlhome_dir ->
      OS.Env.parse "OPAM_SWITCH_PREFIX" OS.Env.path
        ~absent:Fpath.(dkmlhome_dir / "system") )
