open Configurator.V1
open Flags

type platformtype =
  | Android_arm64v8a
  | Android_arm32v7a
  | Android_x86
  | Android_x86_64
  | Darwin_arm64
  | Darwin_x86_64
  | Linux_arm64
  | Linux_arm32v6
  | Linux_arm32v7
  | Linux_x86_64
  | Windows_x86_64
  | Windows_x86

let detect_system_header =
  (* For Apple see https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary *)
  (* For Windows see https://docs.microsoft.com/en-us/cpp/preprocessor/predefined-macros?view=msvc-160 *)
  (* For Android see https://developer.android.com/ndk/guides/cpu-features *)
  (* For Linux see https://sourceforge.net/p/predef/wiki/Architectures/ *)
  {|

  #if __APPLE__
    #include <TargetConditionals.h>
    #if TARGET_OS_OSX
      #define OS_NAME "OSX"
      #if TARGET_CPU_ARM64
        #define PLATFORM_NAME "darwin_arm64"
      #elif TARGET_CPU_X86_64
        #define PLATFORM_NAME "darwin_x86_64"
      #endif
    #elif TARGET_OS_IOS
      #define OS_NAME "IOS"
      #define PLATFORM_NAME "darwin_arm64"
    #endif
  #elif __linux__
    #if __ANDROID__
      #define OS_NAME "Android"
      #if __arm__
        #define PLATFORM_NAME "android_arm32v7a"
      #elif __aarch64__
        #define PLATFORM_NAME "android_arm64v8a"
      #elif __i386__
        #define PLATFORM_NAME "android_x86"
      #elif __x86_64__
        #define PLATFORM_NAME "android_x86_64"
      #endif
    #else
      #define OS_NAME "Linux"
      #if __aarch64__
        #define PLATFORM_NAME "linux_arm64"
      #elif __arm__
        #if defined(__ARM_ARCH_6__) || defined(__ARM_ARCH_6J__) || defined(__ARM_ARCH_6K__) || defined(__ARM_ARCH_6Z__) || defined(__ARM_ARCH_6ZK__) || defined(__ARM_ARCH_6T2__)
          #define PLATFORM_NAME "linux_arm32v6"
        #elif defined(__ARM_ARCH_7__) || defined(__ARM_ARCH_7A__) || defined(__ARM_ARCH_7R__) || defined(__ARM_ARCH_7M__) || defined(__ARM_ARCH_7S__)
          #define PLATFORM_NAME "linux_arm32v7"
        #endif
      #elif __i386__
        #if __x86_64__
          #define PLATFORM_NAME "linux_x86_64"
        #else
          #define PLATFORM_NAME "linux_x86"
        #endif
      #endif
    #endif
  #elif _WIN32
    #define OS_NAME "Windows"
    #if _M_ARM64
      #define PLATFORM_NAME "windows_arm64"
    #elif _M_ARM
      #define PLATFORM_NAME "windows_arm32"
    #elif _WIN64
      #define PLATFORM_NAME "windows_x86_64"
    #elif _M_IX86
      #define PLATFORM_NAME "windows_x86"
    #endif
  #endif
|}

type osinfo = {
  ostypename : (string, string) Result.t;
  platformtypename : (string, string) Result.t;
  platformname : (string, string) Result.t;
}

let get_osinfo t =
  let header =
    let file = Filename.temp_file "discover" "os.h" in
    let fd = open_out file in
    output_string fd detect_system_header;
    close_out fd;
    file
  in
  let os_define =
    C_define.import t ~includes:[ header ] [ ("OS_NAME", String) ]
  in
  let platform_define =
    C_define.import t ~includes:[ header ] [ ("PLATFORM_NAME", String) ]
  in

  let ostypename =
    match os_define with
    | [ (_, String ("Android" as x)) ] -> Result.ok x
    | [ (_, String ("IOS" as x)) ] -> Result.ok x
    | [ (_, String ("Linux" as x)) ] -> Result.ok x
    | [ (_, String ("OSX" as x)) ] -> Result.ok x
    | [ (_, String ("Windows" as x)) ] -> Result.ok x
    | _ -> Result.error "Unknown operating system"
  in

  let platformtypename, platformname =
    match platform_define with
    | [ (_, String ("android_arm64v8a" as x)) ] -> (Result.ok "Android_arm64v8a", Result.ok x)
    | [ (_, String ("android_arm32v7a" as x)) ] -> (Result.ok "Android_arm32v7a", Result.ok x)
    | [ (_, String ("android_x86" as x)) ] -> (Result.ok "Android_x86", Result.ok x)
    | [ (_, String ("android_x86_64" as x)) ] -> (Result.ok "Android_x86_64", Result.ok x)
    | [ (_, String ("darwin_arm64" as x)) ] -> (Result.ok "Darwin_arm64", Result.ok x)
    | [ (_, String ("darwin_x86_64" as x)) ] -> (Result.ok "Darwin_x86_64", Result.ok x)
    | [ (_, String ("linux_arm64" as x)) ] -> (Result.ok "Linux_arm64", Result.ok x)
    | [ (_, String ("linux_arm32v6" as x)) ] -> (Result.ok "Linux_arm32v6", Result.ok x)
    | [ (_, String ("linux_arm32v7" as x)) ] -> (Result.ok "Linux_arm32v7", Result.ok x)
    | [ (_, String ("linux_x86_64" as x)) ] -> (Result.ok "Linux_x86_64", Result.ok x)
    | [ (_, String ("windows_x86_64" as x)) ] -> (Result.ok "Windows_x86_64", Result.ok x)
    | [ (_, String ("windows_x86" as x)) ] -> (Result.ok "Windows_x86", Result.ok x)
    | [ (_, String ("windows_arm64" as x)) ] -> (Result.ok "Windows_arm64", Result.ok x)
    | [ (_, String ("windows_arm32" as x)) ] -> (Result.ok "Windows_arm32", Result.ok x)
    | _ -> (Result.error "Unknown platform", Result.error "Unknown platform")
  in

  { ostypename; platformtypename; platformname }

let () =
  main ~name:"discover" (fun t ->
      let { ostypename; platformtypename; platformname } = get_osinfo t in
      let result_to_string r = match r with | Result.Ok v -> "Result.ok (" ^ v ^ ")" | Result.Error e -> "Result.error (" ^ e ^ ")" in
      let quote_string s = "\"" ^ s ^ "\"" in
      let to_lazy s = "lazy (" ^ s ^ ")" in

      write_lines "target_context.ml"
        [
          (* As you expand the list of platforms and OSes make new versions! Make sure the new platforms and OS give back Result.error in older versions. *)
          {|module V1 = struct|};
          {|  type ostype = Android | IOS | Linux | OSX | Windows|};
          {|  type platformtype =
              | Android_arm64v8a
              | Android_arm32v7a
              | Android_x86
              | Android_x86_64
              | Darwin_arm64
              | Darwin_x86_64
              | Linux_arm64
              | Linux_arm32v6
              | Linux_arm32v7
              | Linux_x86_64
              | Windows_x86_64
              | Windows_x86
              | Windows_arm64
              | Windows_arm32
          |};
          {|  let get_os = |} ^ (result_to_string ostypename |> to_lazy);
          {|  let get_platform = |} ^ (result_to_string platformtypename |> to_lazy);
          {|  let get_platform_name = |} ^ (Result.map quote_string platformname |> result_to_string |> to_lazy);
          {|end (* module V1 *) |};
        ])
