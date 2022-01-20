# Contributors

> This is a placeholder for now.

## Prerequisities

### Windows

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

and on Windows (as long as you installed Diskuv OCaml) you can run:

```powershell
cd contributors/ # if you are not already in this directory
conda activate ./envs
with-dkml make html
explorer .\_build\html\index.html
```

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
