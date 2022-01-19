#######################################
# doc.mk
#
# Requires:
# - base.mk

PUBLISHDOCS_WORKDIR  = _build/.publishdocs

.PHONY: docs-publish
docs-publish:
	@if test -n "$$(git status --porcelain)"; then echo "FATAL: The working directory must be clean! All changes have to be commited to git or removed." >&2; git status --porcelain >&2; exit 1; fi
	$(MAKE) clean

	echo Building OCaml documentation
	install -d _build/
	. '$(DKML_DIR)/vendor/dkml-runtime-common/unix/crossplatform-functions.sh' && autodetect_ocaml_and_opam_home && DKML_FEATUREFLAG_CMAKE_PLATFORM=ON $(DKML_DIR)/runtime/unix/platform-dune-exec.sh -p dev -b Debug -o "$$OPAMHOME" -v "$$OCAMLHOME" build @doc --release

	echo Building Sphinx html twice so that Sphinx cross-references work ...
	$(MAKE) html
	$(MAKE) html

	echo Cloning current git repository inside a work folder ...
	git clone --branch gh-pages "file://$$PWD/.git" $(PUBLISHDOCS_WORKDIR)/
	rsync -avp --delete --copy-links _build/html/ $(PUBLISHDOCS_WORKDIR)/docs
	rsync -avp --delete --copy-links _build/default/_doc/_html/ $(PUBLISHDOCS_WORKDIR)/docs/ocaml/
	touch $(PUBLISHDOCS_WORKDIR)/docs/.nojekyll
	cd $(PUBLISHDOCS_WORKDIR) && git add -A && git commit -m "Updated site"

	echo Trying to open a web browser so you can review the final result ...
	echo "Once you are finished the review, use 'git -C $(PUBLISHDOCS_WORKDIR) push && git push origin gh-pages' to publish the changes"
	if which wslview >/dev/null 2>&1; then wslview _build/.publishdocs/docs/index.html || \
	if which open >/dev/null 2>&1; then open _build/.publishdocs/docs/index.html || \
	if which explorer >/dev/null 2>&1; then explorer _build/.publishdocs/docs/index.html || \
	if which firefox >/dev/null 2>&1; then firefox _build/.publishdocs/docs/index.html || \
	echo "Cannot find a browser. Please review the documentation site at _build/.publishdocs/docs/index.html"

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = .
BUILDDIR      = _build

.PHONY: docs-html

# $(O) is meant as a shortcut for $(SPHINXOPTS).
docs-html:
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
