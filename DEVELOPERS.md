# Developers

## Prerequisites

* You must install the [`glab` GitLab CLI](https://gitlab.com/gitlab-org/cli/#installation).

## Use Cases

### Errata

* For `Stage2-DuneFlavor`, you may need to run it multiple times. The first times you may encounter flakiness:

   ```text
   [build] [ERROR] Could not update repository "default": "...\\build\\pkg\\bump\\msys64\\usr\\bin\\mv.exe ...\\build\\pkg\\bump\\.ci\\o\\repo\\default.new ...\\build\\pkg\\bump\\.ci\\o\\repo\\default" exited with code 1 "/usr/bin/mv: cannot move '...\build\pkg\bump\.ci\o\repo\default.new' to '...\build\pkg\bump\.ci\o\repo\default': Permission denied"
   [build] [ERROR] Initial download of repository failed.
   ```

* For `Stage7-Installer`, you may need to run it twice. The first time you may encounter:

   ```text
   [build] # File "installer/bin/runner_user.ml", line 1, characters 9-54:
   [build] # 1 | let () = Dkml_component_ocamlcompiler_common.register ()
   [build] #              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   [build] # Error: Unbound module Dkml_component_ocamlcompiler_common
   ```

### Rebuilding an installer

1. Run CMake configure (`cmake -G` or a "configure" button in your CMake-enabled IDE)
   with the `ci-reproduce` configuration.

   > The `ci-reproduce` target will use [CMakePresetsGenerated.json](./CMakePresetsGenerated.json)
   > which captures the last git commits of all the [subprojects](./dependencies/fetch-git-projects.cmake)
   > needed by DkML.
   >
   > Other downloads come from `opam install` which has reproducible sources from
   > `diskuv-opam-repository`.
   >
   > TODO: Generate a opam lock file and use whenever `opam install`
   > is run so that `default` repository is snapshotted. -or- Easier ... just
   > do a `git` based checkout of the `default` repository ... in fact make it
   > (`opam-repository`) just like the `diskuv-opam-repository` subproject by
   > using fetch-git-projects.cmake.

2. Run through the following CMake targets **sequentially**:
   1. `Package-Stage02-DuneFlavor`
   2. `Package-Stage04-FullFlavor`
   3. `Package-Stage05-Api`
   4. `Package-Stage07-Installer`

   Consult the [Errata](#errata).

### Creating a new version

1. If you have a build directory:

   * Delete the `build/pkg/bump` directory

2. Run CMake configure (`cmake -G` or a "configure" button in your CMake-enabled IDE)
   with the `develop` configuration.
3. Run one of the `Package-VersionBump-{PRERELEASE,PATCH,MINOR,MAJOR}` targets
4. Rerun CMake configure (ex. `cmake -G`).
5. Run through each of the CMake targets **sequentially** starting from `Package-Stage01-` to
   the highest Stage number. Many stages require a re-configuration based on
   values obtained from the prior stages, so do not skip any targets. Consult the
   [Errata](#errata)
6. Finish with the CMake target `-PublishAssets`.

### Try new installer in CI

How about trying a new installer in CI before a [new version is finished](#creating-a-new-version)?

You can:

1. Do a CMake configure so that [CMakePresetsGenerated.json](./CMakePresetsGenerated.json) is updated with
   the latest git commits.
2. Do:

   ```sh
   git commit -m "ci: Try installer" CMakePresetsGenerated.json
   git push
   for sub in diskuv-opam-repository dkml-compiler dkml-component-curl dkml-component-desktop dkml-component-ocamlcompiler dkml-component-ocamlrun dkml-component-opam dkml-component-unixutils dkml-install-api dkml-installer-ocaml-byte dkml-installer-ocaml dkml-runtime-apps dkml-runtime-common dkml-runtime-distribution dkml-workflows; do
      git -C build/_deps/${sub}-src push
   done
   ```

This saved git commit approach is the reason why in CI we don't just build `dkml` from `diskuv-opam-repository` ... with
the git commits saved we can reproduce the installer on external machines and perhaps codesign if it is good.

## Editing Source Code

### Visual Studio Code

You can edit OCaml code after you have built the `Package-Stage04-FullFlavor` target.

In Visual Studio Code:

1. Go to View > Command Palette and select `OCaml: Select a Sandbox for this Workspace`.
2. Choose "Custom"
3. Enter the following (with the paths changed to reflect your project directory, and the correct DkML version number):

   ```powershell
   Y:\source\dkml\build\pkg\bump\.ci\sd4\bs\bin\opam.exe list --switch 2.1.0 --root Y:/source/dkml/build/pkg/bump/.ci/o -- $prog $args
   ```

### Stages

#### Package-Stage07-Installer

This stage creates the installers. This is the last stage when the CMake option `DKML_GOLDEN_SOURCE_CODE` is set.

#### Package-Stage10-GitPushForTesting

This stage tags and pushes the parent `dkml` project and the `diskuv-opam-repository` project
to Git.

#### Package-Stage12-PublishAssets

This stage will publish all the source archives (ex. dkml-runtime-common.tar.gz) to GitLab. That way
the source urls in `diskuv-opam-repository` can be used.

Stop at this stage if you want to use the `Package-WindowsSandbox` target.

### Dune Build

You can go into directories to build each project you want to edit. For example:

```powershell
cd build\_deps\dkml-runtime-apps-src
Y:\source\dkml\build\pkg\bump\.ci\sd4\bs\bin\opam.exe exec --switch 2.1.0 --root Y:\source\dkml\build\pkg\bump\.ci\o -- dune build
```

### Git

You can do `git commit` in each `build/_deps/*-src` directory. There are `Package-Stage*` targets that will push in changes
at the appropriate times.

### Iterative Development

> Use with **EXTREME CAUTION**

Each iteration:

1. Run in a Unix shell (`with-dkml bash` on Windows) ... use the correct version number:

   ```sh
   delete_git_tag() {
      delete_git_tag_VERSION=$1; shift
      delete_git_tag_PROJECT=$1; shift
      git -C $delete_git_tag_PROJECT tag -d $delete_git_tag_VERSION
      git -C $delete_git_tag_PROJECT push origin --delete $delete_git_tag_VERSION
   }
   next_iteration() {
      next_iteration_VERSION=$1; shift
      delete_git_tag $next_iteration_VERSION .
      delete_git_tag $next_iteration_VERSION build/_deps/diskuv-opam-repository-src
   }
   next_iteration 9.9.9
   ```

2. Go to <https://gitlab.com/dkml/distributions/dkml/-/packages> and **delete** the **same** version number if it exists.
3. Go to <https://gitlab.com/dkml/distributions/dkml/-/releases> and **delete** the **same** version number if it exists.
4. Run the `Package-Stage12-PublishAssets` target.
5. Run the `Package-WindowsSandbox` target. Inside it:
   1. Run `powershell -ExecutionPolicy Bypass tools\install-winget.ps1`
   2. Run `tools\installer-native.cmd`
