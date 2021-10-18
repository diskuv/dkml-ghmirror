(* Adapted from MIT-licensed https://github.com/revery-ui/revery/blob/master/src/Native/config/dune *)
open Configurator.V1
open Flags

type os = Android | IOS | Linux | Mac | Windows

let detect_system_header =
  {|

  #if __APPLE__
    #include <TargetConditionals.h>
    #if TARGET_OS_IPHONE
      #define PLATFORM_NAME "ios"
    #else
      #define PLATFORM_NAME "mac"
    #endif
  #elif __linux__
    #if __ANDROID__
      #define PLATFORM_NAME "android"
    #else
      #define PLATFORM_NAME "linux"
    #endif
  #elif _WIN32
    #define PLATFORM_NAME "windows"
  #endif
|}

let get_os t =
  let header =
    let file = Filename.temp_file "discover" "os.h" in
    let fd = open_out file in
    output_string fd detect_system_header;
    close_out fd;
    file
  in
  let platform =
    C_define.import t ~includes:[ header ] [ ("PLATFORM_NAME", String) ]
  in

  match platform with
  | [ (_, String "android") ] -> Android
  | [ (_, String "ios") ] -> IOS
  | [ (_, String "linux") ] -> Linux
  | [ (_, String "mac") ] -> Mac
  | [ (_, String "windows") ] -> Windows
  | _ -> failwith "Unknown operating system"

let () =
  main ~name:"discover" (fun t ->
      let os = get_os t in
      let ostype =
        match os with
        | Android -> "Android"
        | IOS -> "IOS"
        | Linux -> "Linux"
        | Mac -> "Mac"
        | Windows -> "Windows"
      in
      write_lines "os_context.ml"
        [
          {|type ostype = Android | IOS | Linux | Mac | Windows|};
          {|let host_os = |} ^ ostype;
        ])
