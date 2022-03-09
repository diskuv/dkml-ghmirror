open Rresult
open Dkml_context
open Bos
open Astring

let platform_path_norm s = match (Lazy.force Target_context.V2.get_os) with
| Ok IOS | Ok OSX | Ok Windows -> String.Ascii.lowercase s
| Ok Android | Ok Linux -> s
| Error msg -> Fmt.pf Fmt.stderr "FATAL: %a@\n" Rresult.R.pp_msg msg; exit 1

let path_contains entry s =
  String.find_sub ~sub:(platform_path_norm s) (platform_path_norm entry)
  |> Option.is_some

let path_starts_with entry s =
  String.is_prefix ~affix:(platform_path_norm s) (platform_path_norm entry)

let path_ends_with entry s =
  String.is_suffix ~affix:(platform_path_norm s) (platform_path_norm entry)

(** [prune_path_of_msys2 ()] removes .../MSYS2/usr/bin from the PATH environment variable *)
let prune_path_of_msys2 () =
  OS.Env.req_var "PATH" >>= fun path ->
  String.cuts ~empty:false ~sep:";" path
  |> List.filter (fun entry ->
         let ends_with = path_ends_with entry in
         not (ends_with "\\MSYS2\\usr\\bin"))
  |> fun paths -> Some (String.concat ~sep:";" paths) |> OS.Env.set_var "PATH"

(** Set the MSYSTEM environment variable to MSYS and place MSYS2 binaries at the front of the PATH.
    Any existing MSYS2 binaries in the PATH will be removed.
  *)
let set_msys2_entries target_platform_name =
  Lazy.force get_msys2_dir_opt >>= function
  | None -> R.ok ()
  | Some msys2_dir ->
      (* 1. MSYSTEM = MSYS *)
      OS.Env.set_var "MSYSTEM" (Some "MSYS") >>= fun () ->
      (* 2. MSYSTEM_CARCH, MSYSTEM_CHOST, MSYSTEM_PREFIX for 64-bit MSYS.
          There is no 32-bit MSYS2 tooling (well, 32-bit was deprecated), but you don't need 32-bit
          MSYS2 binaries; just a 32-bit (cross-)compiler.

          See "MSYS" entry for https://www.msys2.org/docs/environments/ for the magic values.
        *)
      (match target_platform_name with
      | "windows_x86" | "windows_x86_64" -> R.ok ("x86_64", "x86_64-pc-msys", "/usr")
      | _ -> R.error_msg @@ "The target platform name '" ^ target_platform_name ^ "' is not a recognized Windows platform")
      >>= fun (carch, chost, prefix) ->
      OS.Env.set_var "MSYSTEM_CARCH" (Some carch) >>= fun () ->
      OS.Env.set_var "MSYSTEM_CHOST" (Some chost) >>= fun () ->
      OS.Env.set_var "MSYSTEM_PREFIX" (Some prefix) >>= fun () ->
      (* 3. Remove MSYS2 entries, if any, from PATH *)
      prune_path_of_msys2 () >>= fun () ->
      (* 4. Add MSYS2 back to front of PATH *)
      OS.Env.req_var "PATH" >>= fun path ->
      OS.Env.set_var "PATH"
        (Some (Fpath.(msys2_dir / "usr" / "bin" |> to_string) ^ ";" ^ path))
