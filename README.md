# Diskuv OCaml 0.3.3

*Diskuv OCaml* is an OCaml distribution focused on a) secure, cross-platform software development and b) ease of use for language learners and professional developers.

**Documentation is available at https://diskuv.gitlab.io/diskuv-ocaml/**

The preview versions 0.2.x run on **64-bit Windows** and:

1. Includes an installer for the initial multi-hour Windows compilation process, including the installation of Git and Visual Studio Build Tools if needed:

   ![Installation Screenshot](https://diskuv.gitlab.io/diskuv-ocaml/_images/Intro-install-world.png)

2. Includes a UNIX-compatible runtime environment for building OCaml applications with common tools like `make`, `opam` and `dune`:

   ```kotlin
    [PS Z:\source\diskuv-ocaml-starter] cd ~/DiskuvOCamlProjects/diskuv-ocaml-starter
    [PS Z:\source\diskuv-ocaml-starter] ./makeit build-dev
    [PS Z:\source\diskuv-ocaml-starter] _build/default/bin/main.exe
    > 1
    > 2
    > 3
    > 94.5
    > Total: 100.5
    [PS Z:\source\diskuv-ocaml-starter] ./makeit shell-dev
   ```

   ```lasso
    [diskuv-ocaml-starter]$ echo You are now running a UNIX shell.
    > You are now running a UNIX shell.
    [diskuv-ocaml-starter]$ opam switch --short
    > C:\Users\you\AppData\Local\Programs\DiskuvOCaml\1\system
    > Z:\source\diskuv-ocaml-starter\build\dev\Debug
    > Z:\source\diskuv-ocaml-starter\build\dev\Release
    > diskuv-boot-DO-NOT-DELETE
    [diskuv-ocaml-starter]$ dune utop
    > ──────────┬─────────────────────────────────────────────────────────────┬──────────
    >           │ Welcome to utop version 2.8.0 (using OCaml version 4.12.0)! │
    >           └─────────────────────────────────────────────────────────────┘
    >
    > Type #utop_help for help about using utop.
    >
    > ─( 06:26:11 )─< command 0 >─────────────────────────────────────────{ counter: 0 }─
   ```

   ```ocaml
    utop #> let square x = x * x ;;
    > val square : int -> int = <fun>
    utop #> square 2 ;;
    > - : int = 4
    utop #> square (square 2) ;;
    > - : int = 16
    utop #> #quit ;;
   ```

3. Works with the OCaml recommended Visual Studio Code plugin:

   ![Screenshot of Visual Studio Code](contributors/doc/diskuv-ocaml-starter.vscode-screenshot.png)

**Please visit our documentation at https://diskuv.gitlab.io/diskuv-ocaml/**

![Twitter Follow](https://img.shields.io/twitter/follow/diskuv?style=social)

## Unix

Install the latest version of Opam before using this distribution. See
https://opam.ocaml.org/doc/Install.html for the latest instructions.

## License

In the [first half of 2022](contributors/doc/Planning/2022-01-A-OpenSourceDiskuvOCaml.rst)
the *Diskuv OCaml* distribution switched to an open-source, liberal
[Apache v2 license](./LICENSE.txt). All non-free source code has been moved to
the *Diskuv SDK* projects.

## Acknowledgements

The *Diskuv OCaml* distribution would not be possible without many people's efforts!

In alphabetical order some of the critical pieces were provided by:

* Andreas Hauptmann (fdopen@) - Maintained the defacto Windows ports of OCaml for who knows how long
* INRIA for creating and maintaining OCaml
* Jane Street and the contributors to `dune`
* OCaml Labs and the contributors for the Visual Studio Code extension for OCaml
* OCamlPro, Jane Street and the contributors to `opam`
* Yaron Minsky, Anil Madhavapeddy and Jason Hickey for the book "Real World OCaml"

## Sponsor

<a href="https://ocaml-sf.org">
<img align="left" alt="OCSF logo" src="https://ocaml-sf.org/assets/ocsf_logo.svg"/>
</a>
Thanks to the <a href="https://ocaml-sf.org">OCaml Software Foundation</a>
for economic support to the development of Diskuv OCaml.
