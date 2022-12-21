# Diskuv OCaml 1.0.1

The Diskuv OCaml distribution is an open-source set of software
that supports software development in pure OCaml. The distribution's
strengths are its:
* full compatibility with OCaml standards like Opam, Dune and ocamlfind
* laser focus on "native" development (desktop software, mobile apps and embedded software) through support for the standard native compilers like Visual Studio
  and Xcode
* ease-of-use through simplified installers and simple productivity commands; high school students should be able to use it
* security through reproducibility, versioning and from-source builds

These alternatives may be better depending on your use case:
* Developing in a Javascript first environment? Have a look at [Esy and Reason](https://esy.sh/)
* Developing operating system kernels? Have a look at [Mirage OS](https://mirage.io/)
* Developing Linux server software like web servers? Plain old [OCaml on Debian, etc.](https://ocaml.org/docs/up-and-running) works well
* Writing compilers or proofs? Plain old OCaml works really well
* Wanting quick installations? *Use anything but Diskuv OCaml!* Diskuv OCaml will conduct
  from-source builds unless it can guarantee (and code sign) the binaries are
  reproducible. Today that means a lot of compiling.

The DKML Installer for OCaml generates and distributes installers for 
the Diskuv OCaml distribution. Windows is ready today; macOS will be available soon.

For news about Diskuv OCaml, 
[![Twitter URL](https://img.shields.io/twitter/url/https/twitter.com/diskuv.svg?style=social&label=Follow%20%40diskuv)](https://twitter.com/diskuv) on Twitter.

**Please visit our documentation at https://diskuv-ocaml.gitlab.io/distributions/dkml/**

## License

In the [first half of 2022](contributors/doc/Planning/2022-01-A-OpenSourceDiskuvOCaml.rst)
the *Diskuv OCaml* distribution switched to an open-source, liberal
[Apache v2 license](./LICENSE.txt). All non-free source code has been moved to
the *Diskuv SDK* projects.

## Sponsor

<a href="https://ocaml-sf.org">
<img align="left" alt="OCSF logo" src="https://ocaml-sf.org/assets/ocsf_logo.svg"/>
</a>
Thanks to the <a href="https://ocaml-sf.org">OCaml Software Foundation</a>
for economic support to the development of Diskuv OCaml.
<p/>

## Acknowledgements

The *Diskuv OCaml* distribution would not be possible without many people's efforts!

Some of the critical pieces were provided by:

* Andreas Hauptmann (fdopen@) - Maintained the defacto Windows ports of OCaml for who knows how long
* INRIA for creating and maintaining OCaml
* Tarides, OCamlPro, Jane Street and the contributors to `dune` and `opam`
