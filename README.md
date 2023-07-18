# DkML 2.0.0

The DkML distribution is an open-source set of software
that supports software development in pure OCaml. The distribution's
strengths are its:

* full compatibility with OCaml standards like Opam, Dune and ocamlfind
* laser focus on "native" development (desktop software, mobile apps and embedded software) through support for the standard native compilers like Visual Studio
  and Xcode
* ease-of-use through simplified installers and simple productivity commands; high school students should be able to use it
* security through reproducibility, versioning and from-source builds

Do not use this distribution if you have a space in your username
(ex. `C:\Users\Jane Smith`).

These alternatives may be better depending on your use case:

* Developing in a Javascript first environment? Have a look at [Esy and Reason](https://esy.sh/)
* Developing operating system kernels? Have a look at [Mirage OS](https://mirage.io/)
* Developing Linux server software like web servers? Plain old [OCaml on Debian, etc.](https://ocaml.org/docs/up-and-running) works well
* Writing compilers or proofs? Plain old OCaml works really well
* Wanting quick installations? *Use anything but DkML!* DkML will conduct
  from-source builds unless it can guarantee (and code sign) the binaries are
  reproducible. Today that means a lot of compiling.

The DKML Installer for OCaml generates and distributes installers for
the DkML distribution. Windows is ready today; macOS will be available soon.

Commercial tools and support are available from Diskuv for mixed OCaml/C
development; however, this pure OCaml distribution only has limited support
for mixed OCaml/C. For example, the `ctypes` opam package has been patched
to work with Visual Studio but is out-dated. Contact
support AT diskuv.com if you need OCaml/C development.

For news about DkML,
[![Twitter URL](https://img.shields.io/twitter/url/https/twitter.com/diskuv.svg?style=social&label=Follow%20%40diskuv)](https://twitter.com/diskuv) on Twitter.

**Please visit our documentation at https://diskuv-ocaml.gitlab.io/distributions/dkml/**

## License

The *DkML* distribution uses an open-source, liberal
[Apache v2 license](./LICENSE.txt).

## Quick Start

After installation, open a new Command Prompt or PowerShell, open
an interactive "*full*" REPL with:

```powershell
C:\> utop-full

(* Real World OCaml book: This is similar to the .ocamlinit
   shown on the book's Installation page.
   Learn more at https://dev.realworldocaml.org/ *)
#require "base";;
open Base;;

(* Real World OCaml book: This is one example from the Error
   Handling section. *)
List.find [1;2;3] ~f:(fun x -> x >= 2);;

(* refl: Type-safe type reflection. Learn more at
   https://github.com/thierry-martinez/refl#readme *)
#require "refl";;
#require "refl.ppx";;

(* refl: PPX-es are macros that generate tedious code for you.
   Here is a basic example of a binary tree type with the
   [@@deriving refl] macro attached. You'll see a ton of
   generated code. *)
type 'a binary_tree =
  | Leaf
  | Node of { left : 'a binary_tree; label : 'a; right : 'a binary_tree }
        [@@deriving refl] ;;

(* refl: Here is an example of how the generated code is
   used. *)
Refl.show [%refl: string binary_tree] []
    (Node { left = Leaf; label = "root"; right = Leaf });;

(* graphics: A simple cross-platform 2D drawing library.
   Learn more at https://ocaml.org/docs/first-hour *)
#require "graphics";;
open Graphics;;

open_graph " 640x480";;

for i = 12 downto 1 do
  let radius = i * 20 in
    set_color (if i mod 2 = 0 then red else yellow);
    fill_circle 320 240 radius
done;;

read_line ();;
```

## Sponsor

<a href="https://ocaml-sf.org">
<img align="left" alt="OCSF logo" src="https://ocaml-sf.org/assets/ocsf_logo.svg"/>
</a>
Thanks to the [OCaml Software Foundation](https://ocaml-sf.org)
for economic support to the development of DkML.
<p/>

## Acknowledgements

The *DkML* distribution would not be possible without many people's efforts!

Some of the critical pieces were provided by:

* Andreas Hauptmann (fdopen@) - Maintained the defacto Windows ports of OCaml for who knows how long
* INRIA for creating and maintaining OCaml
* Tarides, OCamlPro, Jane Street and the contributors to `dune` and `opam`
