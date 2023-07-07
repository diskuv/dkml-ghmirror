# Developers

## Creating a new version

1. If you have a build directory:

   * Delete the `build/pkg/bump` directory

2. Run CMake configure (`cmake -G` or a "configure" button in your CMake-enabled IDE)
3. Run through each of the CMake targets **sequentially** starting from `-Stage0-` to
   the highest Stage number. Many stages require a re-configuration based on
   values obtained from the prior stages, so do not skip any targets.

   Errata:
   1. For Stage2-DuneFlavor, you may need to run it twice. The first time you
      may encounter:

      ```text
      [build] [ERROR] Could not update repository "default": "...\\build\\pkg\\bump\\msys64\\usr\\bin\\mv.exe ...\\build\\pkg\\bump\\.ci\\o\\repo\\default.new ...\\build\\pkg\\bump\\.ci\\o\\repo\\default" exited with code 1 "/usr/bin/mv: cannot move '...\build\pkg\bump\.ci\o\repo\default.new' to '...\build\pkg\bump\.ci\o\repo\default': Permission denied"
      [build] [ERROR] Initial download of repository failed.
      ```

   2. For Stage7-Installer, you may need to run it twice. The first time you
      may encounter:

      ```text
      [build] # File "installer/bin/runner_user.ml", line 1, characters 9-54:
      [build] # 1 | let () = Dkml_component_network_ocamlcompiler.register ()
      [build] #              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      [build] # Error: Unbound module Dkml_component_network_ocamlcompiler
      ```

4. Finish with the CMake target `-PublishAssets`.
