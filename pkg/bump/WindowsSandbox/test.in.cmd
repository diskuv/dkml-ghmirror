ocamlfind printconf
if %errorlevel% neq 0 exit /b %errorlevel%

dune build --root proj1

utop script1/script.ocamlinit

REM Once ocaml has a shim:
REM - ocaml script1/script.ocamlinit