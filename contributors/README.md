# Contributors

> This is a placeholder for now.

## Prerequisities

### Diskuv OCaml

Make sure you have installed Diskuv OCaml.

### Python / Conda

Our instructions assume you have installed Sphinx using [Anaconda](https://www.anaconda.com/products/individual)
or [Miniconda](https://docs.conda.io/en/latest/miniconda.html). Anaconda and Miniconda
are available for Windows, macOS or Linux.

Install a local Conda environment with the following:

```bash
cd contributors/ # if you are not already in this directory
conda create -p envs -c conda-forge sphinx sphinx_rtd_theme rstcheck python-language-server bump2version docutils=0.16 python=3
```

## Building Documentation

On Linux or macOS you can run:

```bash
cd contributors/ # if you are not already in this directory
conda activate ./envs
make html
```

and on Windows you can run:

```powershell
cd contributors/ # if you are not already in this directory
conda activate ./envs
& $env:DiskuvOCamlHome\tools\MSYS2\usr\bin\make.exe html
explorer .\_build\html\index.html
```

## Release Lifecycle

Start the new release on Windows with `release-start-patch`, `release-start-minor`
or `release-start-major`:

```powershell
& $env:DiskuvOCamlHome\tools\MSYS2\usr\bin\make.exe release-start-minor
```

Commit anything that needs changing or fixing, and document your changes/fixes in
the `contributors/changes/vMAJOR.MINOR.PATCH.md` file the previous command created
for you. Do not change the placeholder `@@YYYYMMDD@@` in it though.

When you think you are done, you need to test. Publish a prerelease:

```powershell
& $env:DiskuvOCamlHome\tools\MSYS2\usr\bin\make.exe release-prerelease
```

Test it, and repeat until all problems are fixed.

Finally, after you have *at least one* prerelease:

```powershell
& $env:DiskuvOCamlHome\tools\MSYS2\usr\bin\make.exe release-complete
```
