# CHANGES

## 2.0.0 (2023-07-17)

### Upgrading?

First uninstall the old Diskuv OCaml version using "Add or remove programs" in the Control Panel.

### What do I do after the install is complete?

You SHOULD read the "Install is done! What next?" at <https://diskuv-ocaml.gitlab.io/distributions/dkml/#install-is-done-what-next> documentation.

If you had any existing local switches, upgrade them by doing `dkml init`, `opam upgrade` and `opam install . --deps-only` in the local switch directories.

For projects using [`setup-dkml` (part of  `dkml-workflows`)](https://github.com/diskuv/dkml-workflows#dkml-workflows)
for their GitHub Actions / GitLab CI:

1. Re-run `dkml init`, `opam upgrade` and `opam install . --deps-only` in your project
2. Follow the FOURTH and FIFTH steps of <https://github.com/diskuv/dkml-workflows#configure-your-project>

### Changes

**Breaking change**: The global environment (where you can run `dune`, `utop`,
`ocamlopt` and a few other critical OCaml executables without having
to install your own opam switch) has changed significantly. Follow these
guidelines if you operate frequently in the global environment:

* Use `utop` and `utop-full` like you did in previous versions.
* If you want to use `dune` to compile native code libraries,
  create your own opam switch using `dkml init` in an empty directory.
* If you want to use `dune` to compile bytecode, you can turn on
  a feature flag by doing:

  * In *PowerShell* run `notepad $env:DiskuvOCamlHome\dkmlvars-v2.sexp`
  * Add the line `("DiskuvOCamlMode" ("byte"))` after the
    `DiskuvOCamlVarsVersion` line. Save the file.

More details can be found in the "Global Environment Change Details" section
below.

Why do this breaking change?

1. 2.0.0+ installations are faster because the global executables do not have
   to be compiled.
2. It gets the DkML distribution very close to having a lite "bytecode only"
   installer that does not need to install (heavy!) Visual Studio, MSYS2 and
   Git. This upcoming lite installer should be a good fit for educational
   settings.

Major non-breaking changes:

* The deprecated `fdopen` repository is no longer used. Previously DkML
  installed a smaller and smaller portion of the `fdopen` repository with each
  subsequent version. Now DkML is relies only on the central opam repository
  and the DkML opam repository.
* Dune upgraded to 3.8.3. Among other things, the installer no longer installs
  a C# file watcher proxy for `dune build -w`; instead Dune uses its own
  native Windows file watcher.
* The set of pinned packages during a `dkml init` local switch has gone down
  from approximately 4000 to 200. Rather than pinning each package in the
  opam universe to a heuristically-determined version, we pin only packages
  that we successfully build on Windows.
* The following packages are accessible by just typing `utop` without installing a switch:
  * [`refl`](https://github.com/thierry-martinez/refl#readme) reflection package
  * [`graphics`](https://github.com/ocaml/graphics#readme) package
  * [`base`](https://github.com/janestreet/base#readme) package

Bug fixes:

* The installer can now restart after a failed installation, without having
  to use the uninstaller.
* Allow setup to succeed on Windows filesystems that do not support the setting
  of file attributes
* FlexDLL object files `flexdll_initer_msvc64.obj` and `flexdll_msvc64.obj` (or
  32-bit variant on 32-bit installs) are installed alongside `flexlink.exe` so
  flexlink can be used by itself without setting `FLEXDIR` environment
  variable.

Known issues:

* When you opt into the `("DiskuvOCamlMode" ("byte"))` mode you will get an unfriendly
  `Cannot set stack reserve: File "coff.ml", line 1049, characters 4-10: Assertion failed`
  if you compile or link C code. Dune, for example, will implicitly use the C linker
  (`-output-complete-exe`) in its default rules if you have an `(executable)` clause. Telling
  Dune that you want bytecode using `(executable ... (modes byte))` is necessary but not
  sufficient. You will also explicitly need to use a ".bc" target like
  `dune build src/some-executable.bc` to create pure bytecode, which you can run with
  `dune exec src/some-executable.bc` or `ocamlrun _build/default/src/some-executable.bc`.
  Alternatively, just use `ocamlc` directly to create bytecode.

Changed packages:

| Package             | From                     | To                               |
| ------------------- | ------------------------ | -------------------------------- |
| dune                | 3.6.2                    | 3.8.3 (NOTE1)                    |
| xdg                 | 3.6.2                    | 3.9.0                            |
| utop                | 2.10.0                   | 2.13.1                           |
| ptime               | 0.8.6-msvcsupport        | 1.1.0                            |
| flexdll             | 0.42                     | 0.43                             |
| base                | v0.15.1                  | v0.16.1                          |
| sexplib             | v0.15.1                  | v0.16.0                          |
| stdio               | v0.15.0                  | v0.16.0 (NOTE2)                  |
| conf-pkg-config     | 2                        | 2+cpkgs (NOTE3)                  |
| base64              | 3.5.0                    | 3.5.1                            |
| checkseum           | 0.4.0                    | 0.3.4+android                    |
| cstruct             | 6.1.1                    | 6.2.0                            |
| diskuvbox           | 0.1.1                    | 0.2.0                            |
| extlib              | 1.7.7-1                  | 1.7.9                            |
| fix                 | 20220121                 | 20230505                         |
| mccs                | 1.1+9                    | 1.1+13                           |
| menhir{,Lib,Sdk}    | 20220210                 | 20230608                         |
| omd (double-check)  | 2.0.0~alpha2             | 2.0.0~alpha3                     |
| optint              | 0.2.0                    | 0.3.0                            |
| topkg               | 1.0.6                    | 1.0.7                            |
| yojson              | 2.0.2                    | 2.1.0                            |
| zed                 | 3.2.0                    | 3.2.2                            |
| stdcompat           |                          | 19+optautoconf                   |
| metapp              |                          | 0.4.4+win                        |
| ocamlformat         | 0.24.1                   | 0.25.1                           |
| ocamlformat-rpc-lib | 0.24.1                   | 0.25.1                           |
| lsp                 | 1.12.2                   | 1.16.2                           |
| ocaml-lsp-server    | 1.12.2                   | 1.16.2                           |
| jsonrpc             | 1.12.2                   | 1.16.2                           |
| cmdliner            | 1.1.1                    | 1.2.0                            |
| ocamlbuild          | 0.14.0                   | 0.14.2+win                       |
| bigstringaf         | 0.9.0+msvc               | 0.9.1                            |
| alcotest            | 1.6.0                    | 1.7.0                            |
| ocamlfind           | 1.9.1                    | 1.9.5                            |
| ctypes              | 0.19.2-windowssupport-r5 | 0.19.2-windowssupport-r7 (NOTE5) |
| ctypes-foreign      | 0.19.2-windowssupport-r5 | 0.19.2-windowssupport-r7         |

`dkml init` changes:

* The opam switch variable `dkml-abi` is available after running `dkml init`.
  The `dkml-abi` for 64-bit Windows is `windows_x86_64`.

#### Global Environment Change Details

* In previous versions, a time-consuming `dkml` opam switch was created during
  installation that contained `utop`, etc. The resulting executables were placed
  in the global environment. Since OCaml currently hardcodes library locations
  into executables, `utop` and the other executables (ex. `utop`) would have
  access to everything in the `dkml` opam switch.
* Starting in 2.0.0+, the `dkml` opam switch is no longer created during
  installation. Instead an OCaml native and bytecode compiler is created during
  installation, and separately pre-compiled bytecode libraries and
  pre-compiled shims (ex. `ocamlfind`, `utop`) are provided.
* The shims provide portability for `ocamlfind`, bytecode interpreters
  and bytecode libraries to run from any installation directory. See (NOTE4)
  for more details. Several caveats apply:

  * `ocamlc` and `ocamlopt` are *hardcoded* to access *only* the libraries
    distributed with the OCaml compiler
  * `dune` *defaults* to access *only* the libraries
    distributed with the OCaml compiler
  * `ocamlfind` defaults to finding no libraries; in a future version by default
    it will find *only* the libraries distributed with the OCaml compiler
  * By turning on the `DiskuvOCamlMode` feature flag you can get:

    * `ocamlfind` to find pre-compiled global bytecode libraries
    * `dune` to compile bytecode `.bc` files that reference the same global
      3rd-party libraries (run `ocamlfind list` to see them)

#### Footnotes

* (NOTE1) And all the remaining Dune packages except `xdg`
* (NOTE2) And most of the numerous Jane Street packages
* (NOTE3) `conf-pkg-config.2+cpkgs` downloads a native Windows binary `pkgconf` and
  makes it available to opam as `pkg-config`. *Package maintainers*:
  `pkgconf` supports native Windows slightly better than `pkg-config`. It is
  mostly a drop-in replacement, and `dkml init` (the tool to create switches)
  will set `PKG_CONFIG_PATH` to the location of CLANG64 MSYS2 packages. In a
  future release of DkML after Opam 2.2, CLANG64 MSYS2 packages will be
  installable through depext.
* (NOTE4): To avoid *Inconsistent assumptions over interface* errors all the global
  environment libraries and executables have to be compiled on the same machine:
  either all on the end-user machine (your Windows machine) or all pre-built on a
  CI machine. But in 2.0.0+ only the OCaml compiler and the OCaml standard
  library are compiled on your machine, so if you use `dune` to compile *native*
  code in the global environment your *native* code can only use the OCaml
  standard library.
* (NOTE5): Includes a bug fix for errno handling from Antonin Décimo, and all
  the prior changes in <https://github.com/yallop/ocaml-ctypes/pull/685>

## 1.2.0 (2023-01-24)

**Upgrading?** First uninstall the old Diskuv OCaml version using "Add or remove programs" in the Control Panel.

Callout to **VirtualBox** users: You'll need a workaround for [a not-yet backported FMA fix](https://github.com/ocaml/ocaml/issues/11487) by doing the following in a PowerShell terminal inside VirtualBox _before_ running the installer:

> ```powershell
> mkdir C:\ProgramData\DiskuvOCaml\conf\
> Set-Content -Path "C:\ProgramData\DiskuvOCaml\conf\ocamlcompiler.sexp" -Value "((feature_flag_imprecise_c99_float_ops))"
> ```

Critical changes:

* Switch from the official MSYS2 `msys2-base` install, plus a set of MSYS2
  Internet updates, to a standalone
  [msys2-dkml-base](https://gitlab.com/diskuv-ocaml/distributions/msys2-dkml-base#msys2-dkml-base)
  that has all the MSYS2 packages needed during installation. That removes the
  Internet, GPG keys, proxies, etc. as a source of failures during the MSYS2
  sub-installation.
* Special handling for Scoop package manager on Windows which comingles a
  conflicting bash.exe and git.exe in the same directory. A prior
  `scoop install git` should no longer present a problem during installation.

Performance improvements:

* Plumb the number of cpus to the compiler jobs. [@edwintorok]
* Skip over cross-compiling support when no target ABIs specified.
* Overall shaved ~15 minutes from installation on a 3-CPU machine (80m instead
  of 95m), with additional savings if you have more CPUs.
  Timings in <https://github.com/diskuv/dkml-runtime-common/pull/1>

Component upgrades:

* Bump utop from `2.9.0` to `2.10.0`.
* ocurrent ocaml/opam CI Docker image (a source of pins)
  updated from 2022-02-28 to 2022-11-22; numerous pins updated.

Bug fixes:

* `dkml-runtime-common-native` works with spaces in the Windows home directory
* Removed incorrect `ptime.0.8.6` pin during `dkml init`; now `ptime.1.1.0`

Doc fixes:

* Create `dune-project` in Beyond Basics documentation alongside existing
  `dune init exe` to adhere to Dune 3.x behavior. (Dune 3.6 was added
  in DKML 1.1.0)

Deprecations:

* The `dkml --build-type` build type option will be removed next release. It was
  originally created for Linux builds (perf and AFL variants), and can be
  resurrected and simplified if and when Linux support is added.

Internal changes:

* Added Jane Street's `base` package to global `utop`. In particular, `base` is
  now part of the `dkml` switch created during installation. *`core` is too
  expensive (52 packages) to install automatically, but you can install utop
  and core in your own switch.*
  > For now this is not that useful. The `lib/stublibs` directory of the `dkml`
  > switch needs to be in the PATH for `#require "base";;` to work in global
  > `utop`. That would help readers of the Real World OCaml book. A future
  > release will automate the PATH change.
* Removed `digestif.1.1.2+msvc` pin since MSVC changes upstreamed to 1.1.3.
* The bytecode `*.bc` embedded in the installer is compiled with 4.14.0
  and its embedded runtime is also 4.14.0.
* When using `opam option setenv+=` stop removing the `environment` file to
  force a rebuild of the environment.
* Pin `omd.1.3.1`
* Print timestamp for many logging operations to aid performance comparisons

Patches:

* `base_bigstring.v0.15.0` for MSVC and MinGW (same in fdopen and esy).
  upstream: <https://github.com/janestreet/base_bigstring/pull/3>
* `time_now.v0.15.0` for MSVC.
  upstream: <https://github.com/janestreet/time_now/issues/3>
* `core.v0.15.1` for MSVC.
  upstream: <https://github.com/janestreet/core/pull/161>
* `core_kernel.v0.15.0` for MSVC.
  upstream: <https://github.com/janestreet/core_kernel/pull/107>
* `alcotest.1.6.0` for MSVC.
  upstream: <https://github.com/mirage/alcotest/pull/369>
* `curly.0.2.0` for Windows and MSVC (pending release; already unblocked).
  upstream: <https://github.com/rgrinberg/curly/issues/10>
* `base.v0.15.1` for MSVC 32-bit. Already merged; in v0.16~preview.127.22+307.
  upstream: <https://github.com/janestreet/base/pull/128>

## 1.1.0 (2022-12-27)

Quick Links:
|             |                                                                                                                              |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Installer   | <https://github.com/diskuv/dkml-installer-ocaml/releases/download/v1.1.0_r2/setup-diskuv-ocaml-windows_x86_64-1.1.0.exe>     |
| Uninstaller | <https://github.com/diskuv/dkml-installer-ocaml/releases/download/v1.1.0_r2/uninstall-diskuv-ocaml-windows_x86_64-1.1.0.exe> |

**Upgrading from 1.0.1?**

1. Uninstall the old version first with the uninstaller above!
2. After uninstalling the old version, run the following in PowerShell:

   ```powershell
   if (Test-Path "$env:LOCALAPPDATA\opam\playground") { Remove-Item -Path "$env:LOCALAPPDATA\opam\playground" -Force -Recurse }
   ```

3. Exit Visual Studio Code and any `utop` or `ocaml` sessions. Then
   use the installer above.
4. After installing the new version, run the following in PowerShell **in each directory that has a local opam switch** to upgrade to
   OCaml 4.14.0 and all the other package versions that come with DKML 1.1.0:

   ```powershell
   # Sometimes `dkml init` can fail, but you are OK as long as you see:
   # ...  upgrade   ocaml-system                       4.12.1 to 4.14.0
   dkml init

   opam upgrade
   opam install . --deps-only --with-test
   ```

Cautions:

* Do not use this distribution if you have a space in your username
  (ex. `C:\Users\Jane Smith`). Sorry, but the broader OCaml ecosystem does not
  yet consistently support spaces in directories.
* Your Windows anti-virus may play havoc with the installer. If possible,
  temporarily disable your anti-virus (the "realtime protection",
  "exploit protection" and/or "malware protection" options). Some anti-virus
  products include a button to temporarily disable AV protection for two hours;
  do that. *If you forget and the installer fails, you will need to disable
  AV protection, run the uninstaller, and then rerun the installer!*

New features:

* The system OCaml is 4.14.0 (was 4.12.1)
* The system includes ocamlnat, the experimental native toplevel. It should be
  run using `with-dkml ocamlnat` so native code is compiled with Visual Studio.
* Add odoc 2.1.0 to user PATH, to align with the [OCaml Platform](https://ocaml.org/docs/platform).
* Relocatable native binaries are installed rather than compiled into place.
  Installations should be quicker, which is a pre-requisite for `winget install`
  on Windows.
* Add opam global variable `sys-pkg-manager-cmd-msys2` for future compatibility
  with opam 2.2 depext support of MSYS2
* The `opam dkml init` command is now `dkml init`. The `dkml` executable is
  precompiled and shaves ~20 minutes of installation time.

New security:

* (Advanced; experimental) If you are behind a corporate firewall that uses
  man-in-the-middle (MITM) TLS proxying, you can install your corporate CA chain
  so DKML, in particular MSYS2, does not reject connections. Only persons with
  write access to `$env:ProgramData\DiskuvOCaml\conf\unixutils.sexp` will be
  able to define the allowed MITM TLS chain; you may need access
  from your corporate Administrator. An example `unixutils.sexp` is:

  ```scheme
  (
      (trust_anchors ("C:\\conf\\my.pem" "D:\\conf\\my.cer"))
  )
  ```

  You specify one or more `.pem` or `.cer` CA files, making sure to use two
  backslashes to escape your paths. Your Administrator may have already placed
  the CA files on your machine; otherwise use the guide at
  <https://www.msys2.org/docs/faq/#how-can-i-make-msys2pacman-trust-my-companys-custom-tls-ca-certificate>
  to copy them from your web browsers.

Not so good problems:

* [Known bug #21](https://github.com/diskuv/dkml-installer-ocaml/issues/21) To
  install the OCaml language server in a new switch you will
  need to first do `opam pin remove fiber omd stdune dyn ordering --no-action`
  before doing `opam install ocaml-lsp-server`.
* Many opam packages do not work with the MSVC compiler or with Windows.
  It will take a long time (months, years) to substantially improve Windows
  coverage. When you do find a package that fails to compile on Windows, please
  file an issue with whoever owns the package expressing interest in the
  package working on Windows. Please be patient: some package owners may want
  to see several people express interest before deciding the extra work is
  justified.

Breaking changes:

* Cross-compiling on macOS with dkml-base-compiler now requires you to be explicit
  which CPU architecture you are targeting. Before using `dune -x darwin_arm64`
  would always cross-compile both Intel and Silicon. Now Silicon developers
  need to use `dune -x darwin_x86_64` and Intel developers need to use
  `dune -x darwin_arm64`. The change was necessary to not rely on the presence
  of optional Rosetta2 translation. _Since this cross-compiling feature is little used, it does not warrant a breaking version bump_.

Documentation changes:

* The documentation site has moved to
  <https://diskuv-ocaml.gitlab.io/distributions/dkml/>. Please update your
  bookmarks!

Bug fixes:

* The dune.exe shim uses a cache containing the expensive-to-compute MSVC environment
  settings. A race condition populating the cache has been fixed.
* Repetitive opam repository updates, a source of slowness, were eliminated
  during installation.
* ocaml-crunch upgraded (pinned) from 3.2.0 to 3.3.1 to fix Windows/Unix path
  inconsistency and handling of CRLF. That and other changed package versions
  are:

  | Package             | Old Version | New Version  |
  | ------------------- | ----------- | ------------ |
  | dune                | 2.9.3       | 3.6.2        |
  | ocaml-crunch        | 3.2.0       | 3.3.1        |
  | cmdliner            | 1.0.4       | 1.1.1        |
  | uuidm               | 0.9.7       | 0.9.8        |
  | ptime               | 0.8.6       | 1.1.0        |
  | sexplib             | v0.14.0     | v0.15.1      |
  | lsp                 | 1.9.0       | 1.10.3       |
  | ocaml-lsp-server    | 1.9.0       | 1.10.3       |
  | jsonrpc             | 1.9.0       | 1.10.3       |
  | odoc                | 2.1.0       | 2.2.0        |
  | odoc-parser         | 0.9.0       | 1.0.1        |
  | stdio               | v0.14.0     | v0.15.0      |
  | base                | v0.14.2     | v0.15.1      |
  | mdx                 | 2.0.0       | 2.1.0        |
  | ocamlformat         | 0.19.0      | 0.23.0       |
  | ocamlformat-rpc     | 0.19.0      | _not pinned_ |
  | ocamlformat-rpc-lib | 0.19.0      | 0.23.0       |

* The Visual Studio installation cleans up aborted previous installations.
* The Visual Studio installation, on failure, writes error logs to a location
  that isn't immediately erased.

Component changes:

* ~~opam.exe is compiled directly from the opam master branch; no patches! There
  is still a shim but that shim just sets up environment variables and delegates
  to the authoritative (unpatched) opam.~~ There is one patch for opam on top of
  the opam master branch (opam 2.2) dated 2022-12-21.  
* MSYS2 setup program is bundled inside the installer to lessen download TLS problems
  when a proxy is present (common with corporate/school Windows PCs).
  Resolves <https://github.com/diskuv/dkml-installer-ocaml/issues/19>

Reproducibility features:

* Packages promoted to central Opam repository:
  * dkml-runtime-common
  * dkml-runtime-distribution
  * dkml-component-opam
* Introduce simple spec for which package+versions are installed and/or compiled
  as part of the DKML distribution (in dkml-runtime-distribution). Eventually it
  will become authoritative.
* Introduce dkml-component-desktop which does CI for changes to that spec (aka.
  testing new package versions for Windows using MSVC), and builds all relocatable
  binaries like dune and ocp-indent used in the Windows installer. It is not
  yet in the central Opam repository.
* During installation any `CAMLLIB` environment variable (in addition to
  `OCAMLLIB` which was already checked) is renamed to deconflict with a new
  OCaml installation. Among other things, this provides an upgrade from
  CamlLight to OCaml. <https://github.com/diskuv/dkml-installer-ocaml/issues/13>

Usability tweaks:

* When building DKML packages like dkml-base-compiler, limit dump of Opam
  logs used for troubleshooting to 4 hours

Feature flags:

* Enable `--enable-imprecise-c99-float-ops` during OCaml compilation by setting

  ```scheme
  (
    (feature_flag_imprecise_c99_float_ops)
  )
  ```

  in `$env:ProgramData\DiskuvOCaml\conf\ocamlcompiler.sexp`. This is sometimes
  needed inside virtual machines like Vagrant

Licensing:

* Diskuv OCaml is fully open-source, and is targeted for pure OCaml development.
  Commercial tools and support are available from Diskuv for mixed OCaml/C
  development; however, Diskuv OCaml only has limited support
  for mixed OCaml/C. For example, the `ctypes` opam package has been patched
  to work with Visual Studio but is out-dated. Contact
  support AT diskuv.com if you need OCaml/C development.

Internal changes:

* with-dkml.exe is now configured as a opam wrapper relative to the
  installation directory ($DiskuvOCamlHome) rather than the tools opam switch.
  That change decouples your new switches (aka. opam dkml init) from another
  opam switch.

## 1.0.1 (2022-09-04)

* The installer now checks whether files are in use when overwriting a
  previous installation just like the uninstaller already did.
* Fix Dune shim so `dune build` works consistently on Windows. <https://github.com/diskuv/dkml-installer-ocaml/issues/6>
* Fix detection of Jane Street package versions so `ppx_jane` dependencies like `fieldslib`, and other JS packages,
  are pinned to versions like `v0.14.0` (etc.). Also pin transitive dependencies of `ppx_jane`.
  <https://github.com/diskuv/dkml-installer-ocaml/issues/8>
* MSYS2 variables are available as Opam global variables. See [below](#msys2-variables---101)
* Fix version in Add/Remove Programs that was `dev` instead of `1.0.1` (etc.)

### MSYS2 Variables - 1.0.1

This release adds the following Opam global variables which are assigned from the corresponding
MSYS2 environment variables:

| Global Variable        | Typical Value            | MSYS2 Environment Variable |
| ---------------------- | ------------------------ | -------------------------- |
| `msystem`              | `CLANG64`                | `MSYSTEM`                  |
| `msystem-carch`        | `x86_64`                 | `MSYSTEM_CARCH`            |
| `msystem-chost`        | `x86_64-w64-mingw32`     | `MSYSTEM_CHOST`            |
| `msystem-prefix`       | `/clang64`               | `MSYSTEM_PREFIX`           |
| `mingw-chost`          | `x86_64-w64-mingw32`     | `MINGW_CHOST`              |
| `mingw-prefix`         | `/clang64`               | `MINGW_PREFIX`             |
| `mingw-package-prefix` | `mingw-w64-clang-x86_64` | `MINGW_PACKAGE_PREFIX`     |

> The MSYS2 environment variable values are listed at <https://www.msys2.org/docs/environments/>.
> The authoritative source is <https://github.com/msys2/MSYS2-packages/blob/1ff9c79a6b6b71492c4824f9888a15314b85f5fa/filesystem/msystem>

| Global Variable   | Typical Value                                                      | MSYS2 Command Line |
| ----------------- | ------------------------------------------------------------------ | ------------------ |
| `msys2-nativedir` | `C:\Users\vagrant\AppData\Local\Programs\DiskuvOCaml\tools\MSYS2\` | _`cygpath -aw /`_  |

In addition, `with-dkml.exe` and the Opam and Dune shims now automatically set the `MINGW_{CHOST,PREFIX,PACKAGE_PREFIX}`
environment variables that were missing from prior Diskuv OCaml releases.

These variables let you:

* in Bash (`with-dkml bash`) you can use `pacman -S ${MINGW_PACKAGE_PREFIX}-gcc` to install GCC compiler or
  `pacman -S ${MINGW_PACKAGE_PREFIX}-clang` to install the Clang compiler. Thousands of other packages are
  available at <https://packages.msys2.org/package/?repo=clang64>
* in Opam files (`opam` and `*.opam`) you can use `%{mingw-package-prefix}%`, etc.

*A future release of Diskuv OCaml may automatically install pacman packages using Opam [depext](https://opam.ocaml.org/blog/opam-2-1-0/)*

## 1.0.0 (2022-08-08)

Changes from v0.4.1:

* Uninstaller available
* PATH will no longer have functionally duplicated DOS 8.3 short paths and
  Windows full paths for the binaries installed by Diskuv OCaml

## 0.4.1 (2022-08-01)

Changes:

* [BUG] Fix support for installing to directories with spaces. <https://github.com/diskuv/dkml-installer-ocaml/issues/2>
* [DEBT] Full sync with the pre-2.2 Opam source code except one OPAMROOT patch. <https://github.com/ocaml/opam/issues/3766#issuecomment-1201415069>

## 0.4.0 (2022-06-30)

This release open-sources many of the underlying components in
separate repositories under an Apache 2.0 license:

* [dkml-runtime-common](https://github.com/diskuv/dkml-runtime-common)
* [dkml-runtime-distribution](https://github.com/diskuv/dkml-runtime-distribution)
* [dkml-compiler](https://github.com/diskuv/dkml-compiler)
* [dkml-component-ocamlcompiler](http://github.com/diskuv/dkml-component-ocamlcompiler)
* [dkml-component-ocamlrun](http://github.com/diskuv/dkml-component-ocamlrun)
* [dkml-component-opam](http://github.com/diskuv/dkml-component-opam)
* [dkml-component-curl](http://github.com/diskuv/dkml-component-curl)
* [dkml-component-unixutils](http://github.com/diskuv/dkml-component-unixutils)
* [dkml-install-api](https://diskuv.github.io/dkml-install-api/index.html)
* [dkml-installer-ocaml](http://github.com/diskuv/dkml-installer-ocaml)
* [diskuv-opam-repository](https://github.com/diskuv/diskuv-opam-repository)

The `diskuv-ocaml` repository (what you are reading now) has also changed to
Apache 2.0 and will be kept as the umbrella repository that manages the other
code and Opam repositories.

Opam has been upgraded from 2.1.0 to 2.1.2.

A `playground` switch will automatically be created so you can get started with
OCaml without having to create a switch.

There is partial support for installing in a directory with spaces
(ex. `C:\Users\Alice Cole\AppData\Local`). Only directories that
are on a NTFS volume and which have DOS 8.3 shortname policy enabled
will get the partial support; typically the Windows drive `C:` will
meet the requirements, but USB drives will typically not.
Windows Administrators can set a policy with
[fsutil 8dot3name](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil)
and non-Administrators can change individual directories they
own with `fsutil file setshortname`.

In common situations `with-dkml` does not need to be used:

1. `opam` can be used without `with-dkml opam`
2. `dune` can be used without `with-dkml dune` in any **new** Opam switch you create.
3. `dune` can be used without `with-dkml dune` if you don't use Opam switches.

That means you can just type `dune build` and `opam install graphics`, for example.

**This new form of `dune` will not work in an existing switch.** To recreate your
switch, assuming you have `.opam` files, do the following in PowerShell:

```powershell
cd {existing switch}
opam switch remove $PWD
opam dkml init
(& opam env) -split '\r?\n' | ForEach-Object { Invoke-Expression $_ }
opam install . --deps-only --with-test
```

The new form of Dune also gets `dune build --watch` working. We provided a
`fswatch.exe` for Windows that Dune 2.9 uses to watch the file system.

The deprecated `./makeit` scripts are no longer supported. Those scripts were
deprecated with the introduction of `with-dkml`.

The MSYS2 environment has switched from the base `MSYS` to `CLANG64`, which
means you can install C/C++ packages that are
[compatible with Visual Studio](https://www.msys2.org/docs/environments/) and
have no dependency on MSYS2. The more than 2000 C/C++ packages can be discovered with
[MSYS2 package search of the "clang64" repository](https://packages.msys2.org/package/?repo=clang64) and
installed with [`with-dkml pacman -S <name of package>`](https://www.msys2.org/docs/package-management/).
Just keep the `with-dkml pacman -S pkg1 pkg2 ...` command
in a build script so your C/C++ packages can be reproduced on other machines
or when Diskuv OCaml is upgraded.

The following core packages have been upgraded:

* dune.2.9.1 -> 2.9.3
* ptime.0.8.6-msvcsupport -> 0.8.6
* sha.1.15.1 -> 1.15.2
* fmt.0.8.10 -> 0.9.0
* jingoo.1.4.3 -> 1.4.4
* utop.2.8.0 -> 2.9.0
* (ocaml 4.13.1 only) lsp.1.9.0 -> 1.10.3
* (ocaml 4.13.1 only) ocaml-lsp-server.1.9.0 -> 1.10.3
* (ocaml 4.13.1 only) jsonrpc.1.9.0 -> 1.10.3

All other package versions have been upgraded using the
ocaml/opam Docker image as of [Feb 28, 2022](https://hub.docker.com/layers/ocaml/opam/windows-msvc-ltsc2022-ocaml-4.12/images/sha256-a96f023f0878154170af6471a0f57d1122f7e90ea3f43c33fef2a16e168e1776).

Cygwin is no longer installed on-demand if the Opam repository inside
ocaml/opam Docker image is not available for download. The Opam repository
asset is generated in advance by Diskuv and expected to be downloadable.
Similarly, jq which was used during the Opam repository generation is no
longer installed.

The switches `diskuv-host-tools` and `host-tools` are no longer in use. Instead
the `dkml` switch provides binaries and environments for `utop` and other core
developer tools.

The vcpkg specific logic to discover `vcpkg_installed` and make use of
`DKML_VCPKG_HOST_TRIPLET` and `DKML_VCPKG_MANIFEST_DIR` environment
variables has been removed. `DKML_3P_PROGRAM_PATH` and `DKML_3P_PREFIX_PATH`
are more general replacements described in the
[with-dkml.exe documentation](https://diskuv.gitlab.io/diskuv-ocaml/doc/CommandReference.html#with-dkml-exe)

## 0.3.3 (2022-01-14)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Changes:

* Windows installer would fail when Diskuv zip assets could not be downloaded. Restored behavior
  from earlier versions that would install Cygwin and build the reproducible assets when
  downloads fail.
* Fix regression introduced in 0.3.1 where `opam dkml` would complain of missing PLATFORM
* Mitigate pre- Windows-1909 bug deleting directories when installer cleans a prior installation

## 0.3.2 (2021-12-15)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Changes:

* Windows fixes for older .NET installations and older Windows Server versions. May be a solution for [Intermittent installation failures when installing MSYS2 from mainland China](https://gitlab.com/diskuv/diskuv-ocaml/-/issues/6)

## 0.3.1 (2021-12-13)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Changes:

* Fix [Toplevel file for ocamlfind is not installed in tools system switch, causing hardcoded paths to local switches](https://gitlab.com/diskuv/diskuv-ocaml/-/issues/8)
* Fix [Opam symbolic links on Windows failing without Run as Administrator](https://github.com/ocaml/opam/pull/4962)

## 0.3.0 (2021-11-29)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Breaking Changes:

* [ocamlformat](https://github.com/ocaml-ppx/ocamlformat#should-i-use-ocamlformat) has been upgraded from
  0.18.0 to 0.19.0. Your code formatting will change, and you will need to change your versioned `.ocamlformat`
  configuration. See Upgrading instructions below for how to change `.ocamlformat`.

Changes:

* There is a new Opam plugin you run with `opam dkml`.  Run it alone to get help. You can use `opam dkml init` to
  initialize/upgrade a `_opam` subdirectory from zero or more `*.opam` files (also known as creating a local Opam
  switch). Other commands may be added which should closely follow the command naming of [Yarn](https://yarnpkg.com/cli/init)
* There is now a single "system" OCaml compiler rather than the per-switch "base" OCaml compiler of earlier versions.
  That means creating a new `_opam` subdirectory (Opam switch) is significantly quicker.
* The following "CI" packages (available to both CI and Full flavor installations) have been upgraded and are now
  available with the version numbers below:
  `bos.0.2.1`, `cmdliner.1.0.4`, `crunch.3.2.0`, `dune.2.9.1`, `dune-configurator.2.9.1`, `fmt.0.8.10`,
  `ptime.0.8.6-msvcsupport`, `rresult.0.7.0`, `sha.1.15.1`
* The following packages and their dependencies are new to "CI":
  `opam-client.2.1.0`
* The following "Full" packages have been upgraded and are now available with the version numbers below:
  `lsp.1.9.0`, `ocaml-lsp-server.1.9.0`, `jsonrpc.1.9.0`,
  `ocaml-format.0.19.0`, `ocaml-format-rpc.0.19.0`, `ocaml-format-rpc-lib.0.19.0`

Known issues:

* Installing from mainline China frequently errors out. A short term fix is available at
  <https://gitlab.com/diskuv/diskuv-ocaml/-/issues/6#note_726814601>

### Upgrading from v0.2.0/.../v0.2.6 to v0.3.0

FIRST, to upgrade the system (only necessary on Windows!) run the following in PowerShell:

```powershell
(Test-Path -Path ~\DiskuvOCamlProjects) -or $(ni ~\DiskuvOCamlProjects -ItemType Directory);

iwr `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/0.3.0/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip";

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force;

~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat;
```

SECOND, any `.ocamlformat` files in your projects that have:

```ini
version=0.18.0
```

will need to be changed to:

```ini
version=0.19.0
```

THIRD, (optional) if you have been exploring the `diskuv-ocaml-starter` project, do the following:

```bash
git pull --ff-only
git submodule update --init
./makeit prepare-dev
```

FOURTH, (optional) in each of your SDK Project directories (both Windows + Linux/macOS), do the following:

```bash
git -C vendor/diskuv-ocaml fetch
git -C vendor/diskuv-ocaml reset --hard v0.3.0
git commit -m "Upgrade diskuv-ocaml to 0.3.0" vendor/diskuv-ocaml
./makeit prepare-dev
```

## 0.2.6 (2021-11-22)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Changes:

* OCaml has been upgraded from 4.12.0 to [4.12.1](https://ocaml.org/releases/4.12.1.html).
  [4.13.1](https://ocaml.org/releases/4.13.1.html) is also available but is not yet supported by Diskuv.
* The `system` switch has been renamed to `host-tools` to lessen confusion.
  You can remove the `system` switch after upgrading to save space.
* Introduce "Vanilla OCaml" zip archives for 32-bit and 64-bit at <https://gitlab.com/diskuv/diskuv-ocaml/-/releases>. Contains
  `ocaml.exe`, `ocamlc.opt.exe`, the other `ocaml*.exe` and `flexlink.exe`. Since the standard library directories are hardcoded
  by `ocamlc -config` as `C:/DiskuvOCaml/OcamlSys/32/lib/ocaml` and `C:/DiskuvOCaml/OcamlSys/64/lib/ocaml` the most useful scenario
  is continuous integration (GitHub Actions, etc.) where you can extract the archive to `C:\DiskuvOCaml\OcamlSys\{32|64}`. The archive
  contains reproducible source code which is Apache v2.0 licensed. `ocamlc` must be run from a x64 or x86 Native Tools Command
  Prompt (Visual Studio).
* Work to split DKML (Diskuv OCaml distribution) and DKSDK (Diskuv SDK) has started. DKSDK will support CMake,
  cross-compilation and building desktop/mobile/embedded applications, where DKML will be a full-featured OCaml
  distribution used with native (ie. Microsoft, Apple) compilers.
  * Allow which compiler is chosen in `with-dkml.exe` to be overridden with DKML_TARGET_PLATFORM_OVERRIDE environment variable,
    to support cross-compilation
  * Add feature flag DKML_FEATUREFLAG_CMAKE_PLATFORM=ON environment variable to support passing of compiler settings from CMake
    into Opam and Dune through `with-dkml.exe`
  * Deprecate vcpkg environment variables that influence `with-dkml.exe`; instead any third-party libraries can be accepted
    using the documentation at <https://diskuv.gitlab.io/diskuv-ocaml/doc/CommandReference.html>
* Introduce vagrant to simplify testing Windows installations even on Linux machines. Assuming you have VirtualBox and
  Vagrant installed, just do `cd vagrant/win32 ; vagrant up ; vagrant ssh` to open a Command Prompt terminal. From there you can do
  `with-dkml dune build`, `with-dkml ocamlc ...`, etc. to build and test your application

Known issues:

* Installing from mainline China frequently errors out. A short term fix is available at
  <https://gitlab.com/diskuv/diskuv-ocaml/-/issues/6#note_726814601>

### Upgrading from v0.2.0/.../v0.2.5 to v0.2.6

You will need to:

* _(Windows only)_ upgrade your _Diskuv OCaml_ system
* _(Windows, Linux, macOS)_ upgrade your Local Projects (ex. [diskuv-ocaml-starter](https://gitlab.com/diskuv/diskuv-ocaml-starter))
  which can be done at your leisure **before** the next system upgrade

FIRST, to upgrade the system (only necessary on Windows!) run the following in PowerShell:

```powershell
(Test-Path -Path ~\DiskuvOCamlProjects) -or $(ni ~\DiskuvOCamlProjects -ItemType Directory);

iwr `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/0.2.6/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip";

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force;

~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat;
```

SECOND, in each of your Local Project directories (both Windows + Linux/macOS), do the following:

```bash
git -C vendor/diskuv-ocaml fetch
git -C vendor/diskuv-ocaml reset --hard v0.2.6
git commit -m "Upgrade diskuv-ocaml to 0.2.6" vendor/diskuv-ocaml
./makeit prepare-dev
```

## 0.2.5 (2021-10-13)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Changes:

* (Windows) New binary `with-dkml` will drop you into a MSYS2 shell (ex. `with-dkml bash`) or do a build
  (ex. `with-dkml dune build`) directly from a Command Prompt or PowerShell. The MSVC compiler
  chosen at installation time will be available for use
* All OS-es, not just Windows, are configured to use `with-dkml` as a Opam wrapper to enable versioned vcpkg
  libraries to override system libraries. GCC and clang environment variables will be automatically set
  to find vcpkg
* (Security) Sha256 verified download of vcpkg installer

### Upgrading from v0.2.0/.../v0.2.4 to v0.2.5

You will need to:

* _(Windows only)_ upgrade your _Diskuv OCaml_ system
* _(Windows, Linux, macOS)_ upgrade your Local Projects (ex. [diskuv-ocaml-starter](https://gitlab.com/diskuv/diskuv-ocaml-starter))
  which can be done at your leisure **before** the next system upgrade

FIRST, to upgrade the system (only necessary on Windows!) run the following in PowerShell:

```powershell
(Test-Path -Path ~\DiskuvOCamlProjects) -or $(ni ~\DiskuvOCamlProjects -ItemType Directory);

iwr `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/0.2.5/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip";

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force;

~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat;
```

SECOND, in each of your Local Project directories (both Windows + Linux/macOS), do the following:

```bash
git -C vendor/diskuv-ocaml fetch
git -C vendor/diskuv-ocaml reset --hard v0.2.5
git commit -m "Upgrade diskuv-ocaml to 0.2.5" vendor/diskuv-ocaml
./makeit prepare-dev
```

## 0.2.4 (2021-10-10)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Bug Fixes:

* (Windows) Remove old OCaml installations as best as can be found from your user environment. <https://gitlab.com/diskuv/diskuv-ocaml/-/issues/4>

Changes:

* Fix broken `./makeit shell-dev`
* Fix broken builds when a Local Project has `vcpkg.json` manifests
* Add `ocamlformat-rpc.exe` to PATH so OCaml Language Server can format language type snippets
* `& $env:DiskuvOCamlHome\tools\apps\dkml-opam-wrapper.exe bash` will drop you into a Unix shell without having to have a Local Project

### Upgrading from v0.2.0/.../v0.2.3 to v0.2.4

You will need to:

* _(Windows only)_ upgrade your _Diskuv OCaml_ system
* _(Windows, Linux, macOS)_ upgrade your Local Projects (ex. [diskuv-ocaml-starter](https://gitlab.com/diskuv/diskuv-ocaml-starter))
  which can be done at your leisure **before** the next system upgrade

FIRST, to upgrade the system (only necessary on Windows!) run the following in PowerShell:

```powershell
(Test-Path -Path ~\DiskuvOCamlProjects) -or $(ni ~\DiskuvOCamlProjects -ItemType Directory);

iwr `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/0.2.4/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip";

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force;

~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat;
```

SECOND, in each of your Local Project directories (both Windows + Linux/macOS), do the following:

```bash
git -C vendor/diskuv-ocaml fetch
git -C vendor/diskuv-ocaml reset --hard v0.2.4
git commit -m "Upgrade diskuv-ocaml to 0.2.4" vendor/diskuv-ocaml
./makeit prepare-dev
```

## 0.2.3 (2021-10-08)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

This fixes a critical installation bug in v0.2.2:

* During installation a `dkml-opam-wrapper` command could fail.

See the [full list of changes in v0.2.2](https://gitlab.com/diskuv/diskuv-ocaml/-/blob/4e27c38e18360ea0e1731544fa06660fd78421a9/contributors/changes/v0.2.2.md).

### Upgrading from v0.2.0, v0.2.1 or v0.2.2 to v0.2.3

You will need to:

* _(Windows only)_ upgrade your _Diskuv OCaml_ system
* _(Windows, Linux, macOS)_ upgrade your Local Projects (ex. [diskuv-ocaml-starter](https://gitlab.com/diskuv/diskuv-ocaml-starter))
  which can be done at your leisure **before** the next system upgrade

FIRST, to upgrade the system (only necessary on Windows!) run the following in PowerShell:

```powershell
(Test-Path -Path ~\DiskuvOCamlProjects) -or $(ni ~\DiskuvOCamlProjects -ItemType Directory);

iwr `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/0.2.3/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip";

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force;

~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat;
```

SECOND, in each of your Local Project directories (both Windows + Linux/macOS), do the following:

```bash
git -C vendor/diskuv-ocaml fetch
git -C vendor/diskuv-ocaml reset --hard v0.2.3
git commit -m "Upgrade diskuv-ocaml to 0.2.3" vendor/diskuv-ocaml
./makeit prepare-dev
```

## 0.2.2 (2021-10-07)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Changes:

* Visual Studio fixes. <https://gitlab.com/diskuv/diskuv-ocaml/-/issues/3>
  * Detect and require English language pack for Visual Studio.
  * Fix regression introduced in 0.2.x: Auto-installation of Visual Studio has the Windows 10 SDK but not the Visual Studio compiler.
  * Auto-install Visual Studio VC.Tools component for vcpkg use, in addition to VC.14.26 for OCaml use, if the existing installation is not Visual Studio 16.6.
  * Add VC.14.25 as a compatible version so GitHub Actions on a [windows-2019](https://github.com/actions/virtual-environments) environment works.
* Many changes to support CI, including adding CI flavor so don't need to install utop, etc. when in CI
* Use new binary dkml-opam-wrapper as Opam wrap-{build|install|remove} command to cache detection of MSVC and lessen need to drop into MSYS2 shell explicitly
* Order of magnitude trimming of fdopen packages to speed up basic Windows opam operations (especially those that involve tarring)
* Pin all at once the fdopen and other packages that are part of the DKML distribution
* Pre-alpha support for macOS. Key features like cross-compiling x86_64 on arm64 to build universal binaries have not been included.
* Pre-alpha support for Windows 32-bit. A couple key packages are not yet ready for 32-bit.

Sharp edges:

* Windows makeit targets and Windows opam commands are significantly slower than Unix. Signficant changes to Opam are necessary to close the performance gap; no quick fix
  is available.

## 0.2.1 (2021-09-17)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different licenses;
in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

Changes:

* Improve detection of Visual Studio. Now you can have `VS 2019 C++ x64/x86 build tools (Latest)` from a
  [Visual Studio 2019 version 16.6](https://docs.microsoft.com/en-us/visualstudio/releases/2019/release-notes-v16.6)
  installation or `Microsoft.VisualStudio.Component.VC.14.26.x86.x64` from any Visual Studio 2015 Update 3 or later
  installation.
* Fix inotify-win not being compiled, which is used by `./makeit dkml-devmode`
* Pin `ppxlib` to `0.22.0` to remove the need for <https://github.com/janestreet/ppx_variants_conv/pull/9>
* `ctypes.0.19.2-windowssupport-r3` -> `ctypes.0.19.2-windowssupport-r4` fixes thread local storage

## 0.2.0 (2021-09-13)

> The _Diskuv OCaml_ distribution is available under the
[diskuv-ocaml Fair Source 0.9 license](https://gitlab.com/diskuv/diskuv-ocaml/-/raw/main/LICENSE.txt).
Other assets available on <https://gitlab.com/diskuv/diskuv-ocaml/-/releases> may have different
licenses; in particular source code files that prominently display a
[Apache-2.0 license](https://www.apache.org/licenses/LICENSE-2.0.txt).

### Backwards incompatible changes

Backwards incompatible changes requiring the equivalent of a major version bump
(_using semver minor bump since version is still less than 1.0.0_):

* [Windows only] Changed OPAMROOT from `$env:USERPROFILE/.opam` to `$env:LOCALAPPDATA/opam`
  New and upgraded local projects will automatically use the new OPAMROOT after you have
  run `./makeit prepare-dev` (or `./makeit build-dev`)
* [Windows only] Renamed `make.cmd` to `makeit.cmd` so no PATH collision with GNU/BSD Make

### Critical security fixes

* [Windows only] Download MSYS2 installer with HTTPS rather than HTTP, and SHA256 verify the installer.

### Upgrading from v0.1.0 or v0.1.1 to v0.2.0

You will need to:

* _(Windows only)_ upgrade your _Diskuv OCaml_ system
* _(Windows, Linux, macOS)_ upgrade your Local Projects (ex. [diskuv-ocaml-starter](https://gitlab.com/diskuv/diskuv-ocaml-starter))
  which can be done at your leisure **before** the next system upgrade

FIRST, to upgrade the system (only necessary on Windows!) run the following in PowerShell:

```powershell
(Test-Path -Path ~\DiskuvOCamlProjects) -or $(ni ~\DiskuvOCamlProjects -ItemType Directory);

iwr `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/0.2.0/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip";

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force;

~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat;
```

SECOND, in each of your Local Project directories (both Windows + Linux/macOS), do the following:

```bash
git -C vendor/diskuv-ocaml fetch
git -C vendor/diskuv-ocaml reset --hard v0.2.0
git mv make.cmd makeit.cmd
git commit -m "Upgrade diskuv-ocaml to 0.2.0" vendor/diskuv-ocaml make.cmd makeit.cmd
./makeit prepare-dev
```

### Public Changes

New features:

* [Windows only] Auto-detect existing Visual Studio installations so that no automatic
  installation of Visual Studio Build Tools is performed. That means Administrator
  privileges are not needed if you have Visual Studio with the components that *Diskuv OCaml*
  needs. See `Windows Administrator Installation <https://diskuv.gitlab.io/diskuv-ocaml/doc/AdvancedInstalls/WindowsAdministrator.html>`
  for more details.
* [Windows only] Installs an internal copy of `vcpkg`, which in future releases will act
  as a Windows package manager to supply missing OCaml `depext` external dependencies.
  Limited support is available for Local Projects that have vcpkg manifests.
* Introduce `makeit` for Unix systems so that the same `./makeit` command can be
  communicated for both Windows and Unix users
* [Windows only] OCaml compiler now uses `+options` which enables AFL fuzzing among other things
* [Windows only] Distribute 'opam package manager for 32/bit + 64-bit Windows' as a zip and tar.gz on [diskuv-ocaml Releases](https://gitlab.com/diskuv/diskuv-ocaml/-/releases). They are compiled with Microsoft Visual Studio which means no GNU-licensed DLLs need to be distributed with your applications.
* [Windows only] Distribute 'opam repository of ocaml/opam Docker base image' as a zip and tar.gz on [diskuv-ocaml Releases](https://gitlab.com/diskuv/diskuv-ocaml/-/releases). This
  is currently a clone of fdopen's original MinGW repository, but will track whichever repository the Docker images use in the future
* [Windows only] Remove restriction on spaces in directory names

Security enhancements:

* [Windows only] The 'opam package manager for 32/bit + 64-bit Windows' and 'opam repository of ocaml/opam Docker base image' packages on [diskuv-ocaml Releases](https://gitlab.com/diskuv/diskuv-ocaml/-/releases) include reproducible build scripts for auditing and validation. Much of the reproducibility is already provided by Opam; other pieces include downloading from Git tags and Docker checksum image tags. Since Git tags is a weak form of reproducibility, and since the reproducible build scripts are missing SHA2 checksum validation at each build step, please checksum the artifacts yourself if you need this feature.

Productivity improvements:

* Speed up creating switches by not auto-installing pinned packages simply because
  they have _Diskuv OCaml_ patches
* [Windows only] Speed up _Diskuv OCaml_ installation by removing the automatic download of ocaml/opam Docker images and instead using recompiled, much smaller [diskuv-ocaml Releases](https://gitlab.com/diskuv/diskuv-ocaml/-/releases). More details in _Removed_ section below
* [Windows only] Removed two of six commands needed to install _Diskuv OCaml_ on Windows from scratch.

Known issues:

* During `opam install` the local fdopen-mingw repository ~20MB tarball may be repackaged. If you have several packages and their dependencies to install, this disk I/O may significantly slow down your installation. Some of the performance degradation will be improved with the future trimming of that repository; see the _Deprecated_ section below for more details.
* The initial `vcpkg install` may take more than an hour to complete its commands; on most machines it should initially only take a couple minutes. The problem looks related to <https://github.com/microsoft/vcpkg/issues/10468> and <https://github.com/microsoft/vcpkg/issues/13890> which were prematurely closed without adequate explanation.

New additions for the C language:

* `vcpkg` the C/C++ package manager for native Windows libraries
* `libffi` from vcpkg lets OCaml packages like `conf-libffi` and `ctypes` (currently unstable) use a standardized, cross-platform foreign function interface
* `libuv` from vcpkg supplies the Windows implementation for an upcoming patch of the OCaml bindings package `luv`
* [Windows only] To work around a LINK.EXE bug during 32-bit builds, two
  compiler versions are installed rather than one. The
  `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` ("MSVC v142 - VS 2019 C++ x64/x86 build tools (Latest)")
  compiler used in _Diskuv OCaml_ 0.1.x is necessary for vcpkg and as such is still installed in 0.2.x, but there is now a second compiler `Microsoft.VisualStudio.Component.VC.14.26.x86.x64` ("MSVC v142 - VS 2019 C++ x64/x86 build tools (v14.26)") used for C compiling in Opam packages.

New patches:

* `ocamlbuild.0.14.0` has fdopen@'s patches for MinGW, plus a new patch to let `ocamlbuild -where`
  pass through Windows backslashed paths from `ocamlc -config` without interpreting the backslashes
  as OCaml escape sequences
* `core_kernel.v0.14.2` is not new, but now it is pinned so that the MSYS2 compatible version is
  used consistently

MSYS2 changes:

* `pkg-config` was removed from MSYS2 and replaced with the native Windows `pkgconf` from vcpkg.
  `pkgconf` supplies C headers and libraries to the Microsoft compiler and linker with Windows paths.

### Patches only for OCaml package maintainers

> The packages listed below are patched in _Diskuv OCaml_ and are available in any
> [_Diskuv OCaml_ created switch](https://diskuv.gitlab.io/diskuv-ocaml/doc/CommandReference.html#opt-diskuv-ocaml-installtime-create-opam-switch-sh)
> and in any Local Project.
> They either have open PRs or have not been released to Opam, so they are **highly unstable**
> and _not_ meant for public consumption. They have been provided so that downstream OCaml packages
> (packages that consume _Diskuv OCaml_ patched packages) can be tested by
> downstream OCaml package maintainers.

* `ctypes.0.19.2-windowssupport-r3` which is a few commits past `ctypes.0.19.1`
  with a patch to work with Microsoft compiler toolchain.
  Thanks for substantial review and code contributions from @fdopen and @nojb.
  [ctypes PR685](https://github.com/ocamllabs/ocaml-ctypes/pull/685)
* `mirage-crypto.0.10.4-windowssupport` which is a few commits past `mirage-crypto.0.10.3`
  with a patch to make it work with the Microsoft compiler toolchain.
  [mirage-crypto PR137](https://github.com/mirage/mirage-crypto/pull/137)
* `feather.0.3.0` patched to work with native Windows.
  [feather PR23](https://github.com/charlesetc/feather/pull/23)

### Deprecated

* The **fdopen-mingw** repository will be trimmed greatly in a future release. Currently it has multiple versions
  of many packages and its size causes many Opam commands to be slow. A future release will trim each package to
  only one version, and pin that version for reproducible behavior.

### Removed

* The ocaml/opam Docker images have been removed.
  * The MinGW ocaml/opam Docker image was present only to compile Opam
    into a native Windows executable, but that compilation is done separately with the Microsoft compiler
    and prebundled as a separate tarball.
  * The MSVC ocaml/opam Docker image was present for the fdopen-mingw repository, but as of this release the repository
    is prebundled as a separate `ocaml/opam` tarball.
  * The Docker images will still be downloaded on the rare occasion where the packages are not yet released on Diskuv's
    GitLab release page.
  * In the future, if anything is needed from MinGW, MSYS2 has a MinGW subsytem that is simple to manage.
* Cygwin is no longer automatically installed.
  * Cygwin will still be downloaded on the rare occasion where the `ocaml/opam` package has not yet released on Diskuv's
    GitLab release page.

## 0.1.1 (2021-09-02)

Bug fixes:

* Fix `Installation fails when Windows locale/culture has commas in its number format`. <https://gitlab.com/diskuv/diskuv-ocaml/-/issues/1>

License changes:

* Add Eduardo Rafael (maintainer of Esy)

## 0.1.0 (2021-08-25)

Initial release. Only available for Windows 64-bit.

Enjoy!