ifdef DiskuvOCamlHome
CMAKE = '$(DiskuvOCamlHome)'/tools/cmake/bin/cmake.exe
else
CMAKE = cmake
endif

PUBLISHDOCS_WORKDIR  = _build/.publishdocs
ARCHIVE_MEMBERS = LICENSE.txt README.md etc buildtime installtime runtime .dkmlroot .gitattributes .gitignore

.PHONY: clean
clean:
	$(CMAKE) -E remove_directory _build || $(CMAKE) -E rm -rf _build

.PHONY: install-github-cli
install-github-cli:
	@PATH="$$PATH:/usr/bin:/bin"; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then \
		pacman --sync --needed --noconfirm mingw64/mingw-w64-x86_64-github-cli; \
	fi
	@PATH="/usr/bin:/bin:/mingw64/bin:$$PATH"; if ! which gh >/dev/null 2>&1; then \
		echo "FATAL: GitHub CLI was not installed, and the Makefile does not know how to install it." >&2; exit 1; \
	fi

.PHONY: install-gitlab-cli
install-gitlab-cli:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	if ! which glab >/dev/null 2>&1; then \
		wget https://github.com/profclems/glab/releases/download/v1.20.0/glab_1.20.0_Windows_x86_64.zip -O /tmp/glab.zip && \
		rm -rf /tmp/glab && \
		unzip -d /tmp/glab /tmp/glab.zip && install -d /usr/local/bin && install /tmp/glab/bin/glab.exe /usr/local/bin/; \
	fi

.PHONY: install-gitlab-release-cli
install-gitlab-release-cli:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	if ! which release-cli >/dev/null 2>&1; then \
		wget "https://gitlab.com/api/v4/projects/gitlab-org%2Frelease-cli/packages/generic/release-cli/latest/release-cli-windows-amd64.exe" -O /tmp/release-cli.exe && \
		mv /tmp/release-cli.exe /usr/local/bin; \
	fi

.PHONY: install-zip
install-zip:
	@PATH="$$PATH:/usr/bin:/bin"; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then \
		pacman --sync --needed --noconfirm zip; \
	fi
	@PATH="/usr/bin:/bin:/mingw64/bin:$$PATH"; if ! which zip >/dev/null 2>&1; then \
		echo "FATAL: 'zip' was not installed, and the Makefile does not know how to install it." >&2; exit 1; \
	fi

.PHONY: auth-github-cli
auth-github-cli: install-github-cli
	@PATH="/usr/bin:/bin:/mingw64/bin:$$PATH" ; if which gh.exe >/dev/null 2>&1; then GH=gh.exe; else GH=gh; fi; \
	$$GH auth status || $$GH auth login

.PHONY: auth-gitlab-cli
auth-gitlab-cli: install-gitlab-cli
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; if which glab.exe >/dev/null 2>&1; then GLAB=glab.exe; else GLAB=glab; fi; \
	$$GLAB auth status; \
	if ! $$GLAB auth status 2>&1 | grep -q "Token:"; then \
		echo "Suggested Personal Access Token name: glab.exe `hostname` $(USERNAME) DiskuvOCamlHome/`basename '$(DiskuvOCamlHome)'`"; \
		echo "* Choose default git protocol HTTPS"; \
		echo "* Authenticate Git with your GitLab credentials? Yes"; \
		$$GLAB auth login; \
	fi

.PHONY: release-start-major
release-start-major:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then HOME="$$USERPROFILE"; fi; \
	cd .. && bump2version major --config-file .bumpversion.prerelease.cfg --no-tag --message 'Start v{new_version} release' --verbose && \
	NEW_VERSION=`awk '$$1=="current_version"{print $$NF; exit 0}' .bumpversion.prerelease.cfg` && \
	printf '## %s (@@YYYYMMDD@@)\n\n' $$NEW_VERSION > contributors/changes/v$$NEW_VERSION.md

.PHONY: release-start-minor
release-start-minor:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then HOME="$$USERPROFILE"; fi; \
	cd .. && bump2version minor --config-file .bumpversion.prerelease.cfg --no-tag --message 'Start v{new_version} release' --verbose && \
	NEW_VERSION=`awk '$$1=="current_version"{print $$NF; exit 0}' .bumpversion.prerelease.cfg` && \
	printf '## %s (@@YYYYMMDD@@)\n\n' $$NEW_VERSION > contributors/changes/v$$NEW_VERSION.md

.PHONY: release-start-patch
release-start-patch:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then HOME="$$USERPROFILE"; fi; \
	cd .. && bump2version patch --config-file .bumpversion.prerelease.cfg --no-tag --message 'Start v{new_version} release' --verbose && \
	NEW_VERSION=`awk '$$1=="current_version"{print $$NF; exit 0}' .bumpversion.prerelease.cfg` && \
	printf '## %s (@@YYYYMMDD@@)\n\n' $$NEW_VERSION > contributors/changes/v$$NEW_VERSION.md

.PHONY: _build/distribution-portable.zip
_build/distribution-portable.zip: install-zip
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	set -x && rm -f $(CURDIR)/$@ && install -d _build/release-zip && rm -rf _build/release-zip && install -d _build/release-zip && \
	cd .. && zip -r $(CURDIR)/$@ $(ARCHIVE_MEMBERS) && \
	cd $(CURDIR)/_build/release-zip && install -d diskuv-ocaml && cd diskuv-ocaml && unzip $(CURDIR)/$@ && \
	cd .. && rm -f $(CURDIR)/$@ && zip -r $(CURDIR)/$@ diskuv-ocaml

.PHONY: _build/distribution-portable.tar.gz
_build/distribution-portable.tar.gz:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH" ; \
	install -d _build && rm -f $(CURDIR)/$@ && \
	tar cvCfz .. $(CURDIR)/$@ --owner root --group root --transform 's,^,diskuv-ocaml/,' --no-xattrs $(ARCHIVE_MEMBERS)

.PHONY: release-prerelease
release-prerelease: auth-gitlab-cli install-gitlab-release-cli _build/distribution-portable.zip _build/distribution-portable.tar.gz
	@export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	BVDIR=`which bump2version` && BVDIR=`dirname "$$BVDIR"` && export PATH="$$BVDIR:$$PATH" && bash -x release.sh -p

.PHONY: release-complete
release-complete: auth-gitlab-cli install-gitlab-release-cli _build/distribution-portable.zip _build/distribution-portable.tar.gz
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
