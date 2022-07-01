# Contributors

> This is a placeholder for now.

## Prerequisities

### Windows

> If you are just building or editing the documentation, you may find it easier
> to use a non-Windows system; Diskuv OCaml installation is not yet foolproof.

1. Make sure you have installed Diskuv OCaml. The latest releases are
   available at https://github.com/diskuv/dkml-installer-ocaml/releases
2. Run `with-dkml pacman -S mingw-w64-clang-x86_64-graphviz`. You will need
   to rerun this if you upgrade Diskuv OCaml.

### Python / Conda

Our instructions assume you have installed Sphinx using [Anaconda](https://www.anaconda.com/products/individual)
or [Miniconda](https://docs.conda.io/en/latest/miniconda.html). Anaconda and Miniconda
are available for Windows, macOS or Linux.

Install a local Conda environment with the following:

```bash
cd contributors/ # if you are not already in this directory
conda create -p envs -c conda-forge sphinx esbonio sphinx_rtd_theme rstcheck restructuredtext_lint python-language-server bump2version docutils=0.16 python=3
```

## Building Documentation

On Linux or macOS you can run to get documentation in `_build/html/index.html`:

```bash
cd contributors/ # if you are not already in this directory
conda activate ./envs
make clean
make html ; make html
```

and on Windows (as long as you installed Diskuv OCaml) you can run:

```powershell
cd contributors/ # if you are not already in this directory
conda activate ./envs
with-dkml make clean
with-dkml make html ; with-dkml make html
explorer .\_build\html\index.html
```

## Editing Themes

The theme is in [custom_sphinx_rtd_theme](./themes/custom_sphinx_rtd_theme).

If you are just tweaking the theme, you can edit the minified .css and .js
files in the `./themes/custom_sphinx_rtd_theme/sphinx_rtd_theme/static/` folder.

If you are doing extensive edits to the theme, you must:

1. Install [Yarn](https://yarnpkg.com/getting-started/install)
2. In the `themes/custom_sphinx_rtd_theme` directory run:
   ```bash
   yarn install
   ```
3. Make edits to [themes/custom_sphinx_rtd_theme/src/theme.js](themes/custom_sphinx_rtd_theme/src/theme.js)
   and/or the [SASS files in themes/custom_sphinx_rtd_theme/src/sass](themes/custom_sphinx_rtd_theme/src/sass/).
4. In the `themes/custom_sphinx_rtd_theme` directory run:
   ```bash
   yarn build
   ```

In either case, after editing the theme you must run the [Building Documentation commands](#building-documentation)
to regenerate the documentation.

## Release Lifecycle

Start the new release on Windows with `release-start-patch`, `release-start-minor`
or `release-start-major`:

```powershell
with-dkml make release-start-minor
```

Commit anything that needs changing or fixing, and document your changes/fixes in
the `contributors/changes/vMAJOR.MINOR.PATCH.md` file the previous command created
for you. Do not change the placeholder `@@YYYYMMDD@@` in it though.

When you think you are done, you need to test. Publish a prerelease:

```powershell
with-dkml make release-prerelease
```

Test it, and repeat until all problems are fixed.

Finally, after you have *at least one* prerelease:

```powershell
with-dkml make release-complete
```
