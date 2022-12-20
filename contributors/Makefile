# -----------------------

# Installers of build utilities

.PHONY: install-github-cli
.PHONY: install-gitlab-cli
.PHONY: install-gitlab-release-cli
.PHONY: install-zip
.PHONY: install-powershell
.PHONY: install-shellcheck

ifdef COMSPEC
include os-windows.mk
else
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
include os-darwin.mk
else
ifeq ($(UNAME_S),Linux)
include os-linux.mk
else
$(error We currently do not support doing contributions on '$(UNAME_S)')
endif
endif
endif

# -----------------------

## -----------------------------------------------------------
## BEGIN Opam and Dune basics

create-switch: _opam/.opam-switch/switch-config
.PHONY: create-switch

_opam/.opam-switch/switch-config:
	opam switch create . --formula '"dkml-base-compiler" { >= "4.14.0~" & < "4.14.1~" }' \
	  --yes \
	  --deps-only \
	  --repos diskuv=git+https://github.com/diskuv/diskuv-opam-repository.git#main,default=https://opam.ocaml.org

_opam/bin/dune: _opam/.opam-switch/switch-config
	OPAMSWITCH="$$PWD" && if [ -x /usr/bin/cygpath ]; then OPAMSWITCH=$$(/usr/bin/cygpath -aw "$$OPAMSWITCH"); fi && \
	  opam install dune --yes

## END Opam and Dune basics
## -----------------------------------------------------------

PUBLISHDOCS_WORKDIR  = _build/.publishdocs
ARCHIVE_MEMBERS = LICENSE.txt README.md etc buildtime installtime runtime .dkmlroot .gitattributes .gitignore

.PHONY: clean
clean:
	rm -rf _build

.PHONY: install-release-script-dependencies
install-release-script-dependencies:
	@PATH="$$PATH:/usr/bin:/bin"; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then \
		pacman --sync --needed --noconfirm zip; \
	fi

.PHONY: auth-github-cli
auth-github-cli: install-github-cli
	@PATH="/usr/bin:/bin:/mingw64/bin:$$PATH" ; if which gh.exe >/dev/null 2>&1; then GH=gh.exe; else GH=gh; fi; \
	$$GH auth status || $$GH auth login

.PHONY: auth-gitlab-cli
auth-gitlab-cli: install-gitlab-cli
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; if which glab.exe >/dev/null 2>&1; then GLAB=glab.exe; else GLAB=glab; fi; \
	$$GLAB auth status; \
	if $$GLAB auth status 2>&1 | grep -q "api call failed" || ! $$GLAB auth status 2>&1 | grep -q "Token:"; then \
        if [ -n "$(DiskuvOCamlHome)" ]; then SUFFIX=" DiskuvOCamlHome/`basename '$(DiskuvOCamlHome)'`"; else SUFFIX=; fi; \
		echo "Suggested Personal Access Token name: glab.exe `hostname` $(USERNAME)$$SUFFIX"; \
		echo "* Choose default git protocol HTTPS"; \
		echo "* Authenticate Git with your GitLab credentials? Yes"; \
		$$GLAB auth login; \
	fi

NEW_CHANGE_HEADER = (@@YYYYMMDD@@)\n\n

.PHONY: release-start-major
release-start-major:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then HOME="$$USERPROFILE"; fi; \
	cd .. && bump2version major --config-file .bumpversion.prerelease.cfg --no-tag --verbose && git add . && \
	NEW_VERSION=`awk '$$1=="current_version"{print $$NF; exit 0}' .bumpversion.prerelease.cfg` && \
	printf '## %s $(NEW_CHANGE_HEADER)' $$NEW_VERSION > contributors/changes/v$$NEW_VERSION.md && git add contributors/changes/v$$NEW_VERSION.md && \
	git -C vendor/drc commit -a --message "Start v$$NEW_VERSION release" && \
	git -C vendor/drd commit -a --message "Start v$$NEW_VERSION release" && \
	git -C vendor/diskuv-opam-repository commit -a --message "Start v$$NEW_VERSION release" && \
	git add vendor/drc vendor/drd vendor/diskuv-opam-repository && \
	git commit --message "Start v$$NEW_VERSION release" && \
	git -C vendor/drc push && \
	git -C vendor/drd push && \
	git -C vendor/diskuv-opam-repository push && \
	git push

.PHONY: release-start-minor
release-start-minor:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then HOME="$$USERPROFILE"; fi; \
	cd .. && bump2version minor --config-file .bumpversion.prerelease.cfg --no-tag --verbose && git add . && \
	NEW_VERSION=`awk '$$1=="current_version"{print $$NF; exit 0}' .bumpversion.prerelease.cfg` && \
	printf '## %s $(NEW_CHANGE_HEADER)' $$NEW_VERSION > contributors/changes/v$$NEW_VERSION.md && git add contributors/changes/v$$NEW_VERSION.md && \
	git -C vendor/drc commit -a --message "Start v$$NEW_VERSION release" && \
	git -C vendor/drd commit -a --message "Start v$$NEW_VERSION release" && \
	git -C vendor/diskuv-opam-repository commit -a --message "Start v$$NEW_VERSION release" && \
	git add vendor/drc vendor/drd vendor/diskuv-opam-repository && \
	git commit --message "Start v$$NEW_VERSION release" && \
	git -C vendor/drc push && \
	git -C vendor/drd push && \
	git -C vendor/diskuv-opam-repository push && \
	git push

.PHONY: release-start-patch
release-start-patch:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then HOME="$$USERPROFILE"; fi; \
	cd .. && bump2version patch --config-file .bumpversion.prerelease.cfg --no-tag --verbose && git add . && \
	NEW_VERSION=`awk '$$1=="current_version"{print $$NF; exit 0}' .bumpversion.prerelease.cfg` && \
	printf '## %s $(NEW_CHANGE_HEADER)' $$NEW_VERSION > contributors/changes/v$$NEW_VERSION.md && git add contributors/changes/v$$NEW_VERSION.md && \
	git -C vendor/drc commit -a --message "Start v$$NEW_VERSION release" && \
	git -C vendor/drd commit -a --message "Start v$$NEW_VERSION release" && \
	git -C vendor/diskuv-opam-repository commit -a --message "Start v$$NEW_VERSION release" && \
	git add vendor/drc vendor/drd vendor/diskuv-opam-repository && \
	git commit --message "Start v$$NEW_VERSION release" && \
	git -C vendor/drc push && \
	git -C vendor/drd push && \
	git -C vendor/diskuv-opam-repository push && \
	git push

.PHONY: release-prerelease
release-prerelease: auth-gitlab-cli install-gitlab-release-cli install-release-script-dependencies _opam/bin/dune
	@export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	BVDIR=`which bump2version` && BVDIR=`dirname "$$BVDIR"` && export PATH="$$BVDIR:$$PATH" && bash -x release.sh -p -f

.PHONY: quick-prerelease
quick-prerelease: auth-gitlab-cli install-gitlab-release-cli install-release-script-dependencies _opam/bin/dune
	@export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	BVDIR=`which bump2version` && BVDIR=`dirname "$$BVDIR"` && export PATH="$$BVDIR:$$PATH" && bash -x release.sh -p -q -f

.PHONY: release-complete
release-complete: auth-gitlab-cli install-gitlab-release-cli install-release-script-dependencies _opam/bin/dune
	@export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	BVDIR=`which bump2version` && BVDIR=`dirname "$$BVDIR"` && export PATH="$$BVDIR:$$PATH" && bash -x release.sh

# ----------------------------------------------------------
# BEGIN Documentation

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = .
BUILDDIR      = _build

sphinx-help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: sphinx-help Makefile html

# $(O) is meant as a shortcut for $(SPHINXOPTS).
html: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: publish-prepare-docs
publish-prepare-docs:
	@if test -n "$$(git status --porcelain)"; then echo "FATAL: The working directory must be clean! All changes have to be commited to git or removed."; exit 1; fi
	@$(MAKE) clean

	@$(CMAKE) -E echo Building Sphinx html twice so that Sphinx cross-references work ...
	@$(MAKE) html
	@$(MAKE) html O="-W"

.PHONY: publish-github-docs
publish-github-docs: publish-prepare-docs
	@$(CMAKE) -E echo Cloning current GitHub Pages git repository inside a work folder ...
	@git rev-parse gh-pages >/dev/null 2>&1 || git branch gh-pages origin/gh-pages
	@git clone --branch gh-pages "file://$$PWD/../.git" $(PUBLISHDOCS_WORKDIR)/
	@$(CMAKE) -E copy_directory _build/html/ $(PUBLISHDOCS_WORKDIR)/docs
	@$(CMAKE) -E touch $(PUBLISHDOCS_WORKDIR)/docs/.nojekyll
	@git -C $(PUBLISHDOCS_WORKDIR) add -A
	@GIT_AUTHOR_EMAIL=publish-docs.diskuv@example.net GIT_COMMITTER_EMAIL=publish-docs.diskuv@example.net git -C $(PUBLISHDOCS_WORKDIR) commit -m "Updated site"

	@$(CMAKE) -E echo Trying to open a web browser so you can review the final result ...
	@$(CMAKE) -E echo "Once you are finished the review, use 'git -C $$PWD/$(PUBLISHDOCS_WORKDIR) push && git push origin gh-pages' to publish the changes"
	@wslview _build/.publishdocs/docs/index.html || open _build/.publishdocs/docs/index.html || explorer '_build\.publishdocs\docs\index.html' || \
		$(CMAKE) -E echo "Cannot find a browser. Please review the web site at _build/.publishdocs/docs/index.html"

.PHONY: view-docs
view-docs: publish-prepare-docs
	@$(CMAKE) -E echo Trying to open a web browser so you can review the final result ...
	@$(CMAKE) -E echo "Once you are finished the review, commit in the main branch to publish the changes"
	@wslview _build/html/index.html || open _build/html/index.html || explorer '_build\html\index.html' || \
		$(CMAKE) -E echo "Cannot find a browser. Please review the web site at _build/html/index.html"

# END Documentation
# ----------------------------------------------------------
