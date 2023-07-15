for %%i in ("%~dp0.") do SET "sandbox=%%~fi"

ocamlfind printconf
if %errorlevel% neq 0 exit /b %errorlevel%

dune build --root %sandbox%\proj1
if %errorlevel% neq 0 exit /b %errorlevel%

utop %sandbox%\script1\script.ocamlinit
if %errorlevel% neq 0 exit /b %errorlevel%

REM Once ocaml has a shim:
REM - ocaml script1/script.ocamlinit