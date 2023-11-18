# DkML 2.0.3

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

**Please visit our documentation at <https://diskuv.com/dkmlbook/>**

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

(* sqlite3: A file-based database.
   Learn more at https://mmottl.github.io/sqlite3-ocaml *)
#require "sqlite3";;
open Sqlite3;;

let schema = "CREATE TABLE test_values ( " ^
"    row_id INTEGER NOT NULL, " ^
"    string_col TEXT NULL, " ^
"    int_col INT NULL, " ^
"    int64_col INT NULL, " ^
"    float_col FLOAT NULL, " ^
"    bool_col INT NULL" ^
");" ;;
let insert_sql = "INSERT INTO test_values " ^
   "(row_id, string_col, int_col, int64_col, float_col, bool_col) " ^
   "VALUES (?, ?, ?, ?, ?, ?)" ;;
let select_sql = "SELECT " ^
   "string_col, int_col, int64_col, float_col, bool_col " ^
   "FROM test_values WHERE row_id = ?" ;;

(* Construct database and statements *)
let db = db_open "t_values";;
let rc = exec db schema;;
Printf.printf "Created schema: %s" (Rc.to_string rc);;
let insert_stmt = prepare db insert_sql;;
let select_stmt = prepare db select_sql;;

(* Insert values in row 1 *)
let test_float_val = 56.789 ;;
reset insert_stmt;;
bind insert_stmt 1 (Sqlite3.Data.INT 1L);;
bind insert_stmt 2 (Data.opt_text (Some "Hi Mom"));;
bind insert_stmt 3 (Data.opt_int (Some 1));;
bind insert_stmt 4 (Data.opt_int64 (Some Int64.max_int));;
bind insert_stmt 5 (Data.opt_float (Some test_float_val));;
bind insert_stmt 6 (Data.opt_bool (Some true));;
step insert_stmt;;

(* Fetch data back with values *)
reset select_stmt;;
bind select_stmt 1 (Sqlite3.Data.INT 1L);;
Sqlite3.step select_stmt;;
Data.to_string_exn (column select_stmt 0);;
Data.to_int_exn (column select_stmt 1);;
Data.to_int64_exn (column select_stmt 2);;
Data.to_float_exn (column select_stmt 3);;
Data.to_bool_exn (column select_stmt 4);;
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
