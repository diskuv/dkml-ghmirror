for %%i in ("%~dp0.") do SET "sandbox=%%~fi"

ocamlfind printconf
if %errorlevel% neq 0 exit /b %errorlevel%

REM Windows Sandbox's shared folders write out garbage when trying to
REM compile an .exe (.bc is OK)... probably some security measure. So do all
REM compilation in the temporary folder
robocopy %sandbox%\proj1 %TEMP%\scratch1\proj1 /MIR /S
robocopy %sandbox%\proj2 %TEMP%\scratch1\proj2 /MIR /S

REM Dune as of 3.8.3 requires explicit xxx.bc on the command line or else
REM it will do -output-complete-exe which requires a C linker
dune build --root %TEMP%\scratch1\proj1 ./a.bc
if %errorlevel% neq 0 exit /b %errorlevel%

ocamlrun %TEMP%\scratch1\proj1\_build\default\a.bc
if %errorlevel% neq 0 exit /b %errorlevel%

REM This section works only with native code. (How can we check?)
REM dune build --root %TEMP%\scratch1\proj2
REM if %errorlevel% neq 0 exit /b %errorlevel%
REM dune exec --root %TEMP%\scratch1\proj2 ./best.exe
REM if %errorlevel% neq 0 exit /b %errorlevel%

utop-full %sandbox%\script1\script.ocamlinit
if %errorlevel% neq 0 exit /b %errorlevel%

REM Once ocaml has a shim:
REM - ocaml script1/script.ocamlinit

if not exist "%TEMP%\scratch2" mkdir %TEMP%\scratch2
pushd %TEMP%\scratch2

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