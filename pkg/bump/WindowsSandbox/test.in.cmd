for %%i in ("%~dp0.") do SET "sandbox=%%~fi"

ocamlfind printconf
if %errorlevel% neq 0 exit /b %errorlevel%

REM Dune as of 3.8.3 requires explicit xxx.bc on the command line or else
REM it will do -output-complete-exe which requires a C linker
dune build --root %sandbox%\proj1 ./a.bc
if %errorlevel% neq 0 exit /b %errorlevel%

ocamlrun %sandbox%\proj1\_build\default\a.bc
if %errorlevel% neq 0 exit /b %errorlevel%

utop-full %sandbox%\script1\script.ocamlinit
if %errorlevel% neq 0 exit /b %errorlevel%

REM Once ocaml has a shim:
REM - ocaml script1/script.ocamlinit

if not exist "%TEMP%\scratch" mkdir %TEMP%\scratch
pushd %TEMP%\scratch

dkml init --yes

REM install something with a low number of dependencies, that sufficiently exercises Opam
opam install graphics --yes
if %errorlevel% neq 0 popd & exit /b %errorlevel%

REM regression test: https://discuss.ocaml.org/t/ann-diskuv-ocaml-1-x-x-windows-ocaml-installer-no-longer-in-preview/10309/8?u=jbeckford
opam install ppx_jane --yes
if %errorlevel% neq 0 popd & exit /b %errorlevel%

REM regression test: https://github.com/diskuv/dkml-installer-ocaml/issues/12
opam install pyml --yes
if %errorlevel% neq 0 popd & exit /b %errorlevel%

REM regression test: https://github.com/diskuv/dkml-installer-ocaml/issues/21
opam install ocaml-lsp-server merlin --yes
if %errorlevel% neq 0 popd & exit /b %errorlevel%

opam install ocamlformat --yes
if %errorlevel% neq 0 popd & exit /b %errorlevel%

popd