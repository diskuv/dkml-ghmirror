#######################################
# base.mk

DKML_BASE_VERSION = 0.2.0

ifdef COMSPEC
DKML_NONEMPTY_IF_BUILD_HOST_IS_WINDOWS = ON
else
DKML_NONEMPTY_IF_BUILD_HOST_IS_WINDOWS =
endif

# Utility macros

nullstring :=
space := $(nullstring) # end of the line
comma := ,

# ----------
# Defaults

DKML_BUILD_TRACE ?= ON
# Either `preserve` or `clear-on-rebuild`
DKML_TERMINAL_PERSISTENCE ?= clear-on-rebuild

# ----------


# DKML_PLATFORMS
#
# Which platforms your OCaml application (or library) supports.
# Diskuv OCaml supports windows_x86_64. The list of platforms may expand in the future.
#
# For new architectures the following needs to be updated:
# - this Makefile's DKML_PLATFORMS
# - this Makefile's KERNEL_<platform>
# - this Makefile's ALPINE_ARCH_<platform>
# - this Makefile's VCPKG_TRIPLET_<platform>
# - runtime/unix/build-sandbox-configure.sh :: (BEGIN opam switch create ... END opam switch create)
# - runtime/unix/_common_tool.sh :: build_machine_arch
#
# Naming:
#   DKML_PLATFORMS := KERNEL || '_' || ABI [ || '_' FRAMEWORK]
#   ABI       := application binary interface that encompasses:
#                - the CPU instruction set
#                - the endianness of memory
#                - C/Fortran calling conventions and alignment constraints
#                - executable binary format
#                - C++ name mangling scheme
#  FRAMEWORK  := an optional framework that encompasses:
#                - the SDKs expected on the target device
#             => Darwin options could include "iosdevice", "iossimulator", "macos"
#             => Windows options could include "winstore" (WindowsStore in CMake)
#
# Future Platforms
# ----------------
#
# DKML_PLATFORMS = \
# 	android_arm64v8a \
# 	android_arm32v7a \
# 	android_x86 \
# 	android_x86_64 \
# 	darwin_arm64 \
# 	darwin_x86_64 \
# 	linux_arm64 \
# 	linux_arm32v6 \
# 	linux_arm32v7 \
# 	linux_x86_64 \
# 	windows_x86_64
DKML_PLATFORMS ?=

NOTAPPLICABLE = notapplicable
# KERNEL_xxPLATFORMxx := linux | windows | darwin | android
KERNEL_android_arm64v8a = android
KERNEL_android_arm32v7a = android
KERNEL_android_x86      = android
KERNEL_android_x86_64   = android
KERNEL_darwin_arm64     = darwin
KERNEL_darwin_x86_64    = darwin
KERNEL_linux_arm32v6    = linux
KERNEL_linux_arm32v7    = linux
KERNEL_linux_arm64      = linux
KERNEL_linux_x86_64     = linux
KERNEL_windows_x86_64   = windows
# ANDROID_ABI_xxPLATFORMxx_ := See https://developer.android.com/ndk/guides/abis#sa
ANDROID_ABI_android_arm64v8a = arm64-v8a
ANDROID_ABI_android_arm32v7a = armeabi-v7a
ANDROID_ABI_android_x86      = x86
ANDROID_ABI_android_x86_64   = x86_64
ANDROID_ABI_darwin_arm64     = $(NOTAPPLICABLE)
ANDROID_ABI_darwin_x86_64    = $(NOTAPPLICABLE)
ANDROID_ABI_linux_arm32v6    = $(NOTAPPLICABLE)
ANDROID_ABI_linux_arm32v7    = $(NOTAPPLICABLE)
ANDROID_ABI_linux_arm64      = $(NOTAPPLICABLE)
ANDROID_ABI_linux_x86_64     = $(NOTAPPLICABLE)
ANDROID_ABI_windows_x86_64   = $(NOTAPPLICABLE)
# ALPINE_ARCH_xxPLATFORMxx := See http://mirror.csclub.uwaterloo.ca/alpine/latest-stable/releases/ .
#    The compiler is from the Alpine arch, so this list of Alpine archs will be very fine-grained
#  `native64` means that the build machine must be 64-bit and either the x86_64 or arm64 (Apple M1) Alpine architecture is installed
ALPINE_ARCH_android_arm64v8a = native64
ALPINE_ARCH_android_arm32v7a = native64
ALPINE_ARCH_android_x86      = native64
ALPINE_ARCH_android_x86_64   = native64
ALPINE_ARCH_darwin_arm64     = native64
ALPINE_ARCH_darwin_x86_64    = native64
ALPINE_ARCH_linux_arm32v6    = armhf
ALPINE_ARCH_linux_arm32v7    = armv7
ALPINE_ARCH_linux_arm64      = aarch64
ALPINE_ARCH_linux_x86_64     = x86_64
ALPINE_ARCH_windows_x86_64   = x86_64
# VCPKG_TRIPLET_xxPLATFORMxx  := See https://github.com/microsoft/vcpkg/tree/master/triplets and etc/vcpkg/triplets/
VCPKG_TRIPLET_android_arm64v8a = arm64-android
VCPKG_TRIPLET_android_arm32v7a = arm-android
VCPKG_TRIPLET_android_x86      = x86-android
VCPKG_TRIPLET_android_x86_64   = x64-android
VCPKG_TRIPLET_darwin_arm64     = arm64-osx
VCPKG_TRIPLET_darwin_x86_64    = x64-osx
VCPKG_TRIPLET_linux_arm32v6    = arm-linux-static
VCPKG_TRIPLET_linux_arm32v7    = arm-linux-static
VCPKG_TRIPLET_linux_arm64      = arm64-linux-static
VCPKG_TRIPLET_linux_x86_64     = x64-linux-static
VCPKG_TRIPLET_windows_x86_64   = x64-windows

# All of the build types.
# When modifying, edit:
# - ./dune.env.workspace.inc :: (env ...)
# - ./runtime/unix/build-sandbox-configure.sh :: (BEGIN opam switch create ... END opam switch create)
# - ./dune-workspace :: (context ...)
DKML_BUILDTYPES ?= Debug Release ReleaseCompatPerf ReleaseCompatFuzz
BUILDTYPE_DEFAULT = Debug

HORIZONTAL_RULE_80COLS = "================================================================================"

# ------------------------------------------------------------
# shell-dev runs a shell in the dev platform for build type 'Debug'
# shell-dev-BUILDTYPE runs a shell in the dev platform for build type BUILDTYPE
# shell-PLATFORM runs a shell in PLATFORM's platform for build type 'Debug'
# shell-PLATFORM-BUILDTYPE runs a shell in PLATFORM's platform for build type BUILDTYPE
# shell runs a shell in the dev platform without an Opam switch (unless Opam has a global selected switch)

# Very useful for developing on Windows with `./makeit shell-dev`

define SHELL_platform_template =
.PHONY: shell-$(1)
shell-$(1): shell-$(1)-Debug
endef
$(foreach platform,dev $(DKML_PLATFORMS),$(eval $(call SHELL_platform_template,$(platform))))

define SHELL_platform_buildtype_template =
.PHONY: shell-$(1)-$(2)
shell-$(1)-$(2):
	@if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; DKML_BUILD_TRACE='$(DKML_BUILD_TRACE)' DKMAKE_CALLING_DIR='$(DKMAKE_CALLING_DIR)' '$(DKML_DIR)/runtime/unix/shell.sh' '$(1)' '$(2)' || true
	@exit 0
endef
$(foreach platform,dev $(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), \
    $(eval $(call SHELL_platform_buildtype_template,$(platform),$(buildtype))) \
))

# -----------------------------------------------------------------------------
# prepare-dev|prepare-dev-BUILDTYPE|prepare-PLATFORM|prepare-PLATFORM-BUILDTYPE|
# prepare-all|prepare-all-BUILDTYPE
#
# prepare-dev prepares the dev platform for build type 'Debug'
# prepare-dev-BUILDTYPE prepares the dev platform for build type BUILDTYPE
# prepare-PLATFORM prepares PLATFORM's platform for build type 'Debug'
# prepare-PLATFORM-BUILDTYPE prepares PLATFORM's platform for build type BUILDTYPE
# prepare-all prepares all platforms (except dev) for build type 'Debug'
# prepare-all-BUILDTYPE prepares all platforms (except dev) for build type BUILDTYPE
#
# The many recipes are defined so that `make -j` recipe-based parallelization works well

OPAMS_LINUX   ?= $(OPAM_PKGS_CROSSPLATFORM:=.opam) $(OPAM_PKGS_LINUX:=.opam)
OPAMS_WINDOWS ?= $(OPAM_PKGS_CROSSPLATFORM:=.opam) $(OPAM_PKGS_WINDOWS:=.opam)

OPAMS_CSV_LINUX   ?= $(subst $(space),$(comma),$(addprefix ./,$(strip $(OPAMS_LINUX))))
OPAMS_CSV_WINDOWS ?= $(subst $(space),$(comma),$(addprefix ./,$(strip $(OPAMS_WINDOWS))))

.PHONY: buildconfig/dune
buildconfig/dune: buildconfig/dune/dune.env.workspace.inc buildconfig/dune/dune.env.executable

.PHONY: init-dev
init-dev: buildconfig/dune
	@if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/build-sandbox-init.sh' dev

.PHONY: prepare-dev
prepare-dev: prepare-dev-$(BUILDTYPE_DEFAULT)

define PREPARE_buildtype_template =
  .PHONY: prepare-dev-$(1)
  prepare-dev-$(1): init-dev
	@if [ "$$MSYSTEM" = MSYS ] || [ -e /usr/bin/cygpath ]; then \
		if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/build-sandbox-configure.sh' dev $(1) $(OPAMS_CSV_WINDOWS); \
	else \
		if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/build-sandbox-configure.sh' dev $(1) $(OPAMS_CSV_LINUX); \
	fi

  .PHONY: prepare-all-$(1)
  prepare-all-$(1): $(foreach platform,$(DKML_PLATFORMS),prepare-$(platform)-$(1))
endef
$(foreach buildtype,$(DKML_BUILDTYPES),$(eval $(call PREPARE_buildtype_template,$(buildtype))))

define PREPARE_platform_template =
  .PHONY: init-$(1)
  init-$(1):
	'$(DKML_DIR)/runtime/unix/prepare-docker-alpine-arch.sh' $(1) "$(KERNEL_$(1))" "$(ALPINE_ARCH_$(1))"
	'$(DKML_DIR)/runtime/unix/build-sandbox-init.sh' $(1)

  .PHONY: prepare-$(1)
  prepare-$(1): prepare-$(1)-$(BUILDTYPE_DEFAULT)
endef
$(foreach platform,$(DKML_PLATFORMS),$(eval $(call PREPARE_platform_template,$(platform))))

define PREPARE_platform_buildtype_template =
  .PHONY: prepare-$(1)-$(2)
  prepare-$(1)-$(2): init-$(1)
	'$(DKML_DIR)/runtime/unix/build-sandbox-configure.sh' $(1) $(2) $(LINUX_OPAMS_CSV);
endef
$(foreach platform,$(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), \
    $(eval $(call PREPARE_platform_buildtype_template,$(platform),$(buildtype))) \
))

prepare-all: $(foreach platform,$(DKML_PLATFORMS),prepare-$(platform))

# -----------------------------------------------------------------------------
# clean-dev|clean-dev-BUILDTYPE|clean-PLATFORM|clean-PLATFORM-BUILDTYPE|
# clean-all|clean-all-BUILDTYPE
#
# clean-dev cleans the dev platform for build type 'Debug'
# clean-dev-BUILDTYPE cleans the dev platform for build type BUILDTYPE
# clean-PLATFORM cleans PLATFORM's platform for build type 'Debug'
# clean-PLATFORM-BUILDTYPE cleans PLATFORM's platform for build type BUILDTYPE
# clean-all cleans all platforms (except dev) for build type 'Debug'
# clean-all-BUILDTYPE cleans all platforms (except dev) for build type BUILDTYPE

# .PHONY: clean-dev
# clean-dev: clean-dev-$(BUILDTYPE_DEFAULT)

define CLEAN_buildtype_template =
  .PHONY: clean-dev-$(1) clean-all-$(1)
  clean-dev-$(1):
	rm -rf build/dev/$(1)
	if [ "$(1)" = "$(BUILDTYPE_DEFAULT)" ]; then rm -rf _build; fi
  clean-all-$(1): $(foreach platform,dev $(DKML_PLATFORMS),clean-$(platform)-$(1))
endef
$(foreach buildtype,$(DKML_BUILDTYPES),$(eval $(call CLEAN_buildtype_template,$(buildtype))))

.PHONY: clean-dev-all
clean-dev-all:
	rm -rf build/_tools/dev
	rm -rf build/dev
	rm -rf _build

define CLEAN_platform_template =
  .PHONY: clean-$(1)-all
  clean-$(1)-all:
	rm -rf build/_tools/$(1)
	rm -rf build/$(1)
endef
$(foreach platform,$(DKML_PLATFORMS),$(eval $(call CLEAN_platform_template,$(platform))))

define CLEAN_platform_buildtype_template =
  .PHONY: clean-$(1)-$(2)
  clean-$(1)-$(2):
	rm -rf build/$(1)/$(2)
endef
$(foreach platform,$(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), \
    $(eval $(call CLEAN_platform_buildtype_template,$(platform),$(buildtype))) \
))

# -----------------------------------------------------------------------------
# build-dev|build-dev-BUILDTYPE|build-PLATFORM|build-PLATFORM-BUILDTYPE|
# build-all|build-all-BUILDTYPE
# ... and ...
# quickbuild-dev|quickbuild-dev-BUILDTYPE|quickbuild-PLATFORM|quickbuild-PLATFORM-BUILDTYPE|
# quickbuild-all|quickbuild-all-BUILDTYPE
# ... and ...
# test-dev|test-dev-BUILDTYPE|test-PLATFORM|test-PLATFORM-BUILDTYPE|
# test-all|test-all-BUILDTYPE
#
# build-dev builds the dev platform for build type 'Debug'
# build-dev-BUILDTYPE builds the dev platform for build type BUILDTYPE
# build-PLATFORM builds PLATFORM's platform for build type 'Debug'
# build-PLATFORM-BUILDTYPE builds PLATFORM's platform for build type BUILDTYPE
# build-all builds all platforms (except dev) for build type 'Debug'
# build-all-BUILDTYPE builds all platforms (except dev) for build type BUILDTYPE
#
# ... and ...
#
# quickbuild-* does the same as build-* except does not invoke the prepare-* steps (which was already expected)
#
# ... and ...
#
# test-dev quickbuilds and tests the dev platform for build type 'Debug' if it exists including any test directories
# test-dev-BUILDTYPE quickbuilds and tests the dev platform for build type BUILDTYPE if it exists including any test directories
# test-PLATFORM quickbuilds and tests PLATFORM's platform for build type 'Debug' if it exists including any test directories
# test-PLATFORM-BUILDTYPE quickbuilds and tests PLATFORM's platform for build type BUILDTYPE if it exists including any test directories
# test-all quickbuilds and tests all platforms (including dev) for build type 'Debug' if they exist including any test directories
# test-all-BUILDTYPE quickbuilds and tests all platforms (including dev) for build type BUILDTYPE if they exist including any test directories
#
# The many recipes are defined so that `make -j` recipe-based parallelization works well

DUNETARGET_BUILD_LINUX   ?= $(OCAML_SRC_CROSSPLATFORM)  $(OCAML_SRC_LINUX)
DUNETARGET_BUILD_WINDOWS ?= $(OCAML_SRC_CROSSPLATFORM)  $(OCAML_SRC_WINDOWS)
DUNETARGET_TEST_LINUX    ?= $(DUNETARGET_BUILD_LINUX)   $(OCAML_TEST_CROSSPLATFORM) $(OCAML_TEST_LINUX)
DUNETARGET_TEST_WINDOWS  ?= $(DUNETARGET_BUILD_WINDOWS) $(OCAML_TEST_CROSSPLATFORM) $(OCAML_TEST_WINDOWS)

.PHONY: build-dev quickbuild-dev
quickbuild-dev: quickbuild-dev-Debug
build-dev: build-dev-Debug
test-dev: test-dev-Debug

define BUILD_buildtype_template =
  .PHONY: build-all-$(1) quickbuild-all-$(1) test-all-$(1)
  quickbuild-all-$(1): $(foreach platform,$(DKML_PLATFORMS),quickbuild-$(platform)-$(1))
  build-all-$(1): $(foreach platform,$(DKML_PLATFORMS),build-$(platform)-$(1))
  test-all-$(1): $(foreach platform,dev $(DKML_PLATFORMS),test-$(platform)-$(1))
endef
$(foreach buildtype,$(DKML_BUILDTYPES),$(eval $(call BUILD_buildtype_template,$(buildtype))))

define BUILD_platform_template =
  .PHONY: build-$(1) quickbuild-$(1) test-$(1)
  build-$(1): build-$(1)-$(BUILDTYPE_DEFAULT)
  quickbuild-$(1): quickbuild-$(1)-$(BUILDTYPE_DEFAULT)
  test-$(1): test-$(1)-$(BUILDTYPE_DEFAULT)
endef
$(foreach platform,$(DKML_PLATFORMS),$(eval $(call BUILD_platform_template,$(platform))))

define BUILD_platform_buildtype_template =
  .PHONY: build-$(1)-$(2) quickbuild-$(1)-$(2) test-$(1)-$(2)
  quickbuild-$(1)-$(2):
	@if [ "$$MSYSTEM" = MSYS ] || [ -e /usr/bin/cygpath ]; then \
		if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p $(1) -b $(2) build $(DUNETARGET_BUILD_WINDOWS); \
	else \
		if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p $(1) -b $(2) build $(DUNETARGET_BUILD_LINUX); \
	fi
  build-$(1)-$(2): prepare-$(1)-$(2) quickbuild-$(1)-$(2)
  test-$(1)-$(2):
	@if [ -e "build/$(1)/$(2)/_opam/bin/dune" ]; then \
		printf "\n\n$(HORIZONTAL_RULE_80COLS)\n"; \
		printf "= %-38s%-38s =\n" $(1) $(2); \
		printf "$(HORIZONTAL_RULE_80COLS)\n\n"; \
		if [ "$$MSYSTEM" = MSYS ] || [ -e /usr/bin/cygpath ]; then \
			if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; \
			DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p $(1) -b $(2) build $(DUNETARGET_TEST_WINDOWS); \
			DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p $(1) -b $(2) runtest $(DUNETARGET_TEST_WINDOWS) && echo TESTS PASSED && echo; \
		else \
			if [ ! "$(DKML_BUILD_TRACE)" = OFF ]; then set -x; fi ; \
			DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p $(1) -b $(2) build $(DUNETARGET_TEST_LINUX); \
			DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p $(1) -b $(2) runtest $(DUNETARGET_TEST_LINUX) && echo TESTS PASSED && echo; \
		fi; \
	fi
endef
$(foreach platform,dev $(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), \
    $(eval $(call BUILD_platform_buildtype_template,$(platform),$(buildtype))) \
))
build-all: $(foreach platform,$(DKML_PLATFORMS),build-$(platform))
test-all: $(foreach platform,dev $(DKML_PLATFORMS),test-$(platform))

# ------------------------------------------------------------

# update-dev is for a developer to update their own machine
.PHONY: update-dev
update-dev: prepare-dev
	opam update --switch build/dev

# update-windows_x86_64, etc. defined and used as a template so `make -j` target parallelization works well
define UPDATE_template =
  .PHONY: update-$(1)
  update-$(1): prepare-$(1)
	$(foreach buildtype,$(DKML_BUILDTYPES),
		'$(DKML_DIR)/runtime/unix/within-sandbox' -p $(platform) -b $(buildtype) opam update;
	)
endef
$(foreach platform,$(DKML_PLATFORMS),$(eval $(call UPDATE_template,$(platform))))

update-all: $(foreach platform,$(DKML_PLATFORMS),update-$(platform))

# ------------------------------------------------------------

# upgrade-dev is for a developer to upgrade their own machine
.PHONY: upgrade-dev
upgrade-dev: prepare-dev
	$(foreach buildtype,$(DKML_BUILDTYPES),
		'$(DKML_DIR)/runtime/unix/within-dev' -b $(buildtype) opam upgrade;
	)

# upgrade-windows_x86_64, etc. defined and used as a template so `make -j` target parallelization works well
define UPGRADE_template =
  .PHONY: upgrade-$(1)
  upgrade-$(1): prepare-$(1)
	$(foreach buildtype,$(DKML_BUILDTYPES),
		'$(DKML_DIR)/runtime/unix/within-sandbox' -p $(platform) -b $(buildtype) opam upgrade;
	)
endef
$(foreach platform,$(DKML_PLATFORMS),$(eval $(call UPGRADE_template,$(platform))))

upgrade-all: $(foreach platform,$(DKML_PLATFORMS),upgrade-$(platform))

# ------------------------------------------------------------
#
# Generate/regenerate the compiler and linker flag include files for all target platforms and build types.
#
# These targets will create empty .sexp files for any missing permutations of PLATFORM and BUILDTYPE.
# **But** ultimately CMake is responsible for placing it own C compiler settings into some of the .sexp
# files (in particular the `*all*.sexp`) files.
# Note: The .sexp files are numbered in order of precedence. So `1-*.sexp` are included before `2-*.sexp`.
#
# See doc/BUILDING.md for a more detailed description.

# Defines some of the https://dune.readthedocs.io/en/stable/dune-files.html#env settings.
# Currently we have:
# - (ocamlopt_flags ...)
#
# You can add more by adding to the $(foreach option,flag1 flag2 flag3, ....) clause
# NIT: Do not copy this recipe! Instead copy the more correct `buildconfig/dune/dune.env.executable` recipe (it has proper dependency triggers, and doesn't generate temporary files and 'cmp -s' checks when not needed)
buildconfig/dune/dune.env.workspace.inc: $(DKML_DIR)/etc/dune/dune.env.workspace.inc.in
	@install -d buildconfig/dune/workspace
	@cp '$<' $@.tmp
	@echo '(env' >> $@.tmp
	@$(foreach platform,dev $(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), \
		echo '  ($(platform)-$(buildtype)' >> $@.tmp; \
		$(foreach option,ocamlopt_flags,\
			if [ ! -e buildconfig/dune/workspace/1-base.$(option).sexp ]; then echo '(:standard) ; Used in dune.env.workspace.inc. See https://dune.readthedocs.io/en/stable/concepts.html#id2 for how to remove flags'    > buildconfig/dune/workspace/1-base.$(option).sexp; fi; \
			if [ ! -e buildconfig/dune/workspace/2-$(platform)-all.$(option).sexp ]; then echo '() ; Used in dune.env.workspace.inc. See https://dune.readthedocs.io/en/stable/concepts.html#ordered-set-language'         > buildconfig/dune/workspace/2-$(platform)-all.$(option).sexp; fi; \
			if [ ! -e buildconfig/dune/workspace/3-all-$(buildtype).$(option).sexp ]; then echo '(); Used in dune.env.workspace.inc. See https://dune.readthedocs.io/en/stable/concepts.html#ordered-set-language'         > buildconfig/dune/workspace/3-all-$(buildtype).$(option).sexp; fi; \
			if [ ! -e buildconfig/dune/workspace/4-$(platform)-$(buildtype).$(option).sexp ]; then echo '(); Used in dune.env.workspace.inc. See https://dune.readthedocs.io/en/stable/concepts.html#ordered-set-language' > buildconfig/dune/workspace/4-$(platform)-$(buildtype).$(option).sexp; fi; \
			echo '    ($(option) \
						(:include "%{project_root}/buildconfig/dune/workspace/1-base.$(option).sexp") \
						(:include "%{project_root}/buildconfig/dune/workspace/2-$(platform)-all.$(option).sexp") \
						(:include "%{project_root}/buildconfig/dune/workspace/3-all-$(buildtype).$(option).sexp") \
						(:include "%{project_root}/buildconfig/dune/workspace/4-$(platform)-$(buildtype).$(option).sexp") \
						)' >> $@.tmp; \
		) \
		echo '  )' >> $@.tmp; \
	))
	@echo ')' >> $@.tmp
	@if [ ! -e $@ ] || ! diff --ignore-trailing-space --brief $@.tmp $@; then \
		mv $@.tmp $@; \
	else rm -f $@.tmp; fi

# Defines some of the https://dune.readthedocs.io/en/stable/dune-files.html#executable settings.
# Currently we have:
# - (link_flags ...)
#
# You can add more by adding to the DUNE_EXECUTABLE_OVERRIDE_OPTIONS variable
DUNE_EXECUTABLE_OVERRIDE_OPTIONS = link_flags

define DUNEENVEXEC_option_template =
  buildconfig/dune/executable/1-base.$(1).sexp:
	@install -d buildconfig/dune/executable
	@[ -e $$@ ] || echo '(:standard) ; Used as an (:include) in (executable) stanzas after being merged by `$(DKML_DIR)/buildtime/sexp_merge_configurator`. See https://dune.readthedocs.io/en/stable/concepts.html#id2 for how to remove flags' > $$@
endef
$(foreach option,$(DUNE_EXECUTABLE_OVERRIDE_OPTIONS),$(eval $(call DUNEENVEXEC_option_template,$(option))))

define DUNEENVEXEC_option_platform_template =
  buildconfig/dune/executable/2-$(2)-all.$(1).sexp: buildconfig/dune/executable/1-base.$(1).sexp
	@[ -e $$@ ] || echo '() ; Used as an (:include) in (executable) stanzas after being merged by `$(DKML_DIR)/buildtime/sexp_merge_configurator`. See https://dune.readthedocs.io/en/stable/concepts.html#ordered-set-language' > $$@
endef
$(foreach option,$(DUNE_EXECUTABLE_OVERRIDE_OPTIONS),$(foreach platform,dev $(DKML_PLATFORMS),$(eval $(call DUNEENVEXEC_option_platform_template,$(option),$(platform)))))

define DUNEENVEXEC_option_buildtype_template =
  buildconfig/dune/executable/3-all-$(2).$(1).sexp: buildconfig/dune/executable/1-base.$(1).sexp
	@[ -e $$@ ] || echo '() ; Used as an (:include) in (executable) stanzas after being merged by `$(DKML_DIR)/buildtime/sexp_merge_configurator` . See https://dune.readthedocs.io/en/stable/concepts.html#ordered-set-language' > $$@
endef
$(foreach option,$(DUNE_EXECUTABLE_OVERRIDE_OPTIONS),$(foreach buildtype,$(DKML_BUILDTYPES),$(eval $(call DUNEENVEXEC_option_buildtype_template,$(option),$(buildtype)))))

define DUNEENVEXEC_option_platform_buildtype_template =
  buildconfig/dune/executable/4-$(2)-$(3).$(1).sexp: buildconfig/dune/executable/2-$(2)-all.$(1).sexp buildconfig/dune/executable/3-all-$(3).$(1).sexp
	@[ -e $$@ ] || echo '() ; Used as an (:include) in (executable) stanzas after being merged by `$(DKML_DIR)/buildtime/sexp_merge_configurator` . See https://dune.readthedocs.io/en/stable/concepts.html#ordered-set-language' > $$@
endef
$(foreach option,$(DUNE_EXECUTABLE_OVERRIDE_OPTIONS),$(foreach platform,dev $(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), \
    $(eval $(call DUNEENVEXEC_option_platform_buildtype_template,$(option),$(platform),$(buildtype))) \
)))

.PHONY: buildconfig/dune/dune.env.executable
buildconfig/dune/dune.env.executable: $(foreach option,$(DUNE_EXECUTABLE_OVERRIDE_OPTIONS),$(foreach platform,dev $(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), buildconfig/dune/executable/4-$(platform)-$(buildtype).$(option).sexp )))

# -----------------------------------------------------------------------------

.PHONY: dkml-report
dkml-report: buildconfig/dune
	@echo DKML Report $(DKML_BASE_VERSION)
	@echo
	@echo PATH = $$PATH
	@echo
	@$(foreach platform,dev $(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES), \
			if [ -e build/$(platform)/$(buildtype)/_opam/bin/dune ]; then \
				echo; \
				echo "$(HORIZONTAL_RULE_80COLS)"; \
				printf "= %-38s%-38s =\n" $(buildtype) $(platform); \
				echo "$(HORIZONTAL_RULE_80COLS)"; \
				echo; \
				if [ "$(platform)" = dev ]; then \
				  within="'$(DKML_DIR)/runtime/unix/within-dev' -b $(buildtype)"; \
				else \
				  within="'$(DKML_DIR)/runtime/unix/within-sandbox' -p $(platform) -b $(buildtype)"; \
				fi; \
				DKML_BUILD_TRACE=OFF $$within uname -a || true; \
				echo; \
				DKML_BUILD_TRACE=OFF '$(DKML_DIR)/runtime/unix/platform-opam-exec' -p $(platform) -b $(buildtype) config report || true; \
				echo; \
				DKML_BUILD_TRACE=OFF '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p $(platform) -b $(buildtype) printenv --display=quiet || true; \
			fi; \
	))

# Sleep for 5 seconds on Dune crash so that developer has plenty of time to press Ctrl-C to kill the while loop
.PHONY: dkml-devmode
dkml-devmode: quickbuild-dev-Debug
	while true; do \
		DKML_BUILD_TRACE=$(DKML_BUILD_TRACE) '$(DKML_DIR)/runtime/unix/platform-dune-exec' -p dev -b Debug \
			build --watch --terminal-persistence=clear-on-rebuild \
			$(if $(DKML_NONEMPTY_IF_BUILD_HOST_IS_WINDOWS),$(DUNETARGET_TEST_WINDOWS),$(DUNETARGET_TEST_LINUX)); \
		sleep 5 || exit 0; \
	done
