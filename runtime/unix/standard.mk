#######################################
# standard.mk
#
# Purpose: Defines `shell`, `build`, `test` and `quickbuild` some of which are common
# targets in many Makefiles. If you have an existing Makefile, you rarely want to include this
# Makefile. Instead include the `base.mk`.
#
# Requires:
# - DKML_DIR (Makefile variable)
# - DKML_PLATFORMS (Makefile variable)
#
# Optional:
# - DKML_BUILDTYPES (Makefile variable). Must be a subset of: Debug Release ReleaseCompatPerf ReleaseCompatFuzz

include $(DKML_DIR)/runtime/unix/base.mk
include $(DKML_DIR)/runtime/unix/doc.mk

.PHONY: shell
shell: # DKMAKE_CALLING_DIR set by make.cmd
	@. '$(DKML_DIR)/etc/contexts/linux-build/crossplatform-functions.sh' && DKML_BUILD_TRACE='$(DKML_BUILD_TRACE)' log_trace env DKMAKE_CALLING_DIR='$(DKMAKE_CALLING_DIR)' SHELL_SCRIPTFILE=$(SHELL_SCRIPTFILE) "$$SHELL" '$(DKML_DIR)/runtime/unix/shell.sh' 'dev' '' || true
	@exit 0

.PHONY: build quickbuild test
ifeq ($(FORCE_CRAZY_BUILD),ON)
build: $(foreach platform,$(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES),build-$(platform)-$(buildtype)))
quickbuild: $(foreach platform,$(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES),build-$(platform)-$(buildtype)))
else
BUILD_ALL_ERROR = $(error \
		Building all target platforms and all build types is rarely what is wanted. \
		You probably should use 'make build-all' to build the Debug build for all target platforms, or \
		'make build-Release' to build the Release build for all target platforms. See doc/BUILDING.md for \
		many more examples. \
		If this is truly what you want to do, use 'make build FORCE_CRAZY_BUILD=ON' or 'make quickbuild FORCE_CRAZY_BUILD=ON'.\
	)
build: ; $(BUILD_ALL_ERROR)
quickbuild: ; $(BUILD_ALL_ERROR)
endif

# `test` quickbuilds and tests all platforms (including dev) for all build types **if they exist** including any test directories
# This is usually the right test target to run.
test: $(foreach platform,dev $(DKML_PLATFORMS),$(foreach buildtype,$(DKML_BUILDTYPES),test-$(platform)-$(buildtype)))
