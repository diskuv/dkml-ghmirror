/*
  For Apple see https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary
  For Windows see https://docs.microsoft.com/en-us/cpp/preprocessor/predefined-macros?view=msvc-160
  For Android see https://developer.android.com/ndk/guides/cpu-features
  For Linux see https://sourceforge.net/p/predef/wiki/Architectures/
 */
#ifndef DKMLCOMPILERPROBE_H
#define DKMLCOMPILERPROBE_H

#if __APPLE__
#   include <TargetConditionals.h>
#   if TARGET_OS_OSX
#       define OS_NAME "OSX"
#       if TARGET_CPU_ARM64
#           define PLATFORM_NAME "darwin_arm64"
#       elif TARGET_CPU_X86_64
#           define PLATFORM_NAME "darwin_x86_64"
#       endif /* TARGET_CPU_ARM64, TARGET_CPU_X86_64 */
#   elif TARGET_OS_IOS
#       define OS_NAME "IOS"
#       define PLATFORM_NAME "darwin_arm64"
#   endif /* TARGET_OS_OSX, TARGET_OS_IOS */
#elif __linux__
#   if __ANDROID__
#       define OS_NAME "Android"
#       if __arm__
#           define PLATFORM_NAME "android_arm32v7a"
#       elif __aarch64__
#           define PLATFORM_NAME "android_arm64v8a"
#       elif __i386__
#           define PLATFORM_NAME "android_x86"
#       elif __x86_64__
#           define PLATFORM_NAME "android_x86_64"
#       endif /* __arm__, __aarch64__, __i386__, __x86_64__ */
#   else
#       define OS_NAME "Linux"
#       if __aarch64__
#           define PLATFORM_NAME "linux_arm64"
#       elif __arm__
#           if defined(__ARM_ARCH_6__) || defined(__ARM_ARCH_6J__) || defined(__ARM_ARCH_6K__) || defined(__ARM_ARCH_6Z__) || defined(__ARM_ARCH_6ZK__) || defined(__ARM_ARCH_6T2__)
#               define PLATFORM_NAME "linux_arm32v6"
#           elif defined(__ARM_ARCH_7__) || defined(__ARM_ARCH_7A__) || defined(__ARM_ARCH_7R__) || defined(__ARM_ARCH_7M__) || defined(__ARM_ARCH_7S__)
#               define PLATFORM_NAME "linux_arm32v7"
#           endif /* __ARM_ARCH_6__ || ...,  __ARM_ARCH_7__ || ... */
#       elif __i386__
#           if __x86_64__
#               define PLATFORM_NAME "linux_x86_64"
#           else
#               define PLATFORM_NAME "linux_x86"
#           endif /* __x86_64__ */
#       endif /* __aarch64__, __arm__, __i386__ */
#   endif /* __ANDROID__ */
#elif _WIN32
#   define OS_NAME "Windows"
#   if _M_ARM64
#       define PLATFORM_NAME "windows_arm64"
#   elif _M_ARM
#       define PLATFORM_NAME "windows_arm32"
#   elif _WIN64
#       define PLATFORM_NAME "windows_x86_64"
#   elif _M_IX86
#       define PLATFORM_NAME "windows_x86"
#   endif /* _M_ARM64, _M_ARM, _WIN64, _M_IX86 */
#endif

#endif /* DKMLCOMPILERPROBE_H */
