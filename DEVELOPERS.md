# Developers

## Creating a new version

1. If you have a build directory:

   * Delete the `build/pkg/bump` directory

2. Run CMake configure (`cmake -G` or a "configure" button in your CMake-enabled IDE)
   with `windows_x86_64` or another OS-specific configuration.
3. Run one of the `Package-VersionBump-{PRERELEASE,PATCH,MINOR,MAJOR}` targets
4. Rerun CMake configure (ex. `cmake -G`).
5. Run through each of the CMake targets **sequentially** starting from `Package-Stage0-` to
   the highest Stage number. Many stages require a re-configuration based on
   values obtained from the prior stages, so do not skip any targets.

   Errata:
   1. For Stage2-DuneFlavor, you may need to run it multiple times. The first times you
      may encounter flakiness:

      ```text
      [build] [ERROR] Could not update repository "default": "...\\build\\pkg\\bump\\msys64\\usr\\bin\\mv.exe ...\\build\\pkg\\bump\\.ci\\o\\repo\\default.new ...\\build\\pkg\\bump\\.ci\\o\\repo\\default" exited with code 1 "/usr/bin/mv: cannot move '...\build\pkg\bump\.ci\o\repo\default.new' to '...\build\pkg\bump\.ci\o\repo\default': Permission denied"
      [build] [ERROR] Initial download of repository failed.
      ```

   2. For Stage7-Installer, you may need to run it twice. The first time you
      may encounter:

      ```text
      [build] # File "installer/bin/runner_user.ml", line 1, characters 9-54:
      [build] # 1 | let () = Dkml_component_ocamlcompiler_common.register ()
      [build] #              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      [build] # Error: Unbound module Dkml_component_ocamlcompiler_common
      ```

6. Finish with the CMake target `-PublishAssets`.

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

### Dune Build

You can go into directories to build each project you want to edit. For example:

```powershell
cd build\_deps\dkml-runtime-apps-src
Y:\source\dkml\build\pkg\bump\.ci\sd4\bs\bin\opam.exe exec --switch 2.1.0 --root Y:\source\dkml\build\pkg\bump\.ci\o -- dune build
```

### Git

You can do `git commit` in each `build/_deps/*-src` directory. There are `Package-Stage*` targets that will push in changes
at the appropriate times.
