@ECHO OFF

SETLOCAL ENABLEEXTENSIONS

SET DKMAKE_CALLING_DIR=%CD%

REM ---------------------------------------------
REM Command file for running Makefile using MSYS2
REM ---------------------------------------------
REM
REM Q: Why MSYS2 rather than Cygwin?
REM Ans: MSYS2 environment is supported in CMake as a first-class citizen. Cygwin is not.
REM
REM Q: Why not use the standard MSYS2 launchers?
REM Ans: We don't like the standard MSYS2 launchers at https://www.msys2.org/wiki/Launchers/
REM because they launch a new window. This is very intrusive to the development experience.
REM Of course the launchers are useful since sometimes the Windows Console is very messed,
REM but we haven't found that to be the case when running make.exe in Command Prompt
REM or VS Code Terminal (PowerShell) or Windows Terminal (PowerShell).
REM
REM So we mimic as best we can the environment that the msys2.exe would give us in whatever
REM console we were invoked from.
REM
REM Here is the real PATH on a standard Windows installation:
REM   PATH=/usr/local/bin:/usr/bin:/bin:/opt/bin:/c/Windows/System32
REM        :/c/Windows:/c/Windows/System32/Wbem
REM        :/c/Windows/System32/WindowsPowerShell/v1.0/:/usr/bin/site_perl
REM        :/usr/bin/vendor_perl:/usr/bin/core_perl
REM
REM Q: Why use the Windows Git executable when MSYS2 already provides one?
REM Ans: Without a filesystem cache Git can be very very slow on Windows.
REM Confer with https://github.com/msysgit/msysgit/wiki/Diagnosing-why-Git-is-so-slow#enable-the-filesystem-cache .
REM MSYS does not (cannot?) take advantage of the filesystem cache that Git for Windows provides.
REM So as long as the `git config core.fscache true` was run after `git clone XXX ; cd XXX` and
REM we use Git for Windows executable then git will be fast.
REM Oddly `git status` speed is important for Opam since it calls `git status` frequently. If
REM Opam is running super slow, try `GIT_TRACE=1 git status` to see if your git is taking more than
REM 100ms.
REM Ans: Windows Git inside MSYS2 can let `git fetch` take advantage of Windows authentication. You
REM may be prompted for username and password if you let MSYS2's /usr/bin/git try to figure out
REM authentication.
REM
REM Important Notes:
REM * We need to provide commonality between Unix builds and Windows builds. In
REM   particular we need to give access to Windows CMake which can generate a MSYS2
REM   build system as a first class citizen (although Ninja is better if the projects
REM   support it).
REM ==» So we'll add Windows CMake to the **front** of the PATH and also put CL.EXE.
REM
REM * Any variables we define here will appear inside the Makefile.
REM ==» Use DKMAKE_INTERNAL_ as prefix for all variables.

REM Set DiskuvOCamlHome if unset
IF defined DiskuvOCamlHome GOTO HaveDiskuvOCamlHome
SET "DKMAKE_INTERNAL_DOCH_PARENT=%LOCALAPPDATA%\Programs\DiskuvOCaml"
if not exist "%DKMAKE_INTERNAL_DOCH_PARENT%\dkmlvars.cmd" (
	echo.
	echo.The %DKMAKE_INTERNAL_DOCH_PARENT%\dkmlvars.cmd script was not found. Make sure you have run
	echo.the script 'installtime\windows\install-world.ps1' once.
	echo.
	exit /b 1
)
CALL "%DKMAKE_INTERNAL_DOCH_PARENT%\dkmlvars.cmd"
IF not defined DiskuvOCamlHome (
	echo.
	echo.The '%DKMAKE_INTERNAL_DOCH_PARENT%\dkmlvars.cmd' script is missing the definition
	echo.for DiskuvOCamlHome. Make sure you have run
	echo.the script 'installtime\windows\install-world.ps1' once.
	echo.
	exit /b 1
)

REM Set DiskuvOCamlMSYS2Dir if unset
:HaveDiskuvOCamlHome
IF defined DiskuvOCamlMSYS2Dir GOTO HaveDiskuvOCamlMSYS2Dir
if not exist "%DiskuvOCamlHome%\..\dkmlvars.cmd" (
	echo.
	echo.The '%DiskuvOCamlHome%\..\dkmlvars.cmd' script was not found. Make sure you have run
	echo.the script 'installtime\windows\install-world.ps1' once.
	echo.
	exit /b 1
)
CALL "%DiskuvOCamlHome%\..\dkmlvars.cmd"
IF not defined DiskuvOCamlMSYS2Dir (
	echo.
	echo.The '%DiskuvOCamlHome%\..\dkmlvars.cmd' script is missing the definition
	echo.for DiskuvOCamlMSYS2Dir. Make sure you have run
	echo.the script 'installtime\windows\install-world.ps1' once.
	echo.
	exit /b 1
)

REM Find .dkmlroot in an ancestor of the current scripts' directory
REM Set DKMLDIR which is used by most Diskuv OCaml scripts through _common_tool.sh, etc.
:HaveDiskuvOCamlMSYS2Dir
FOR /F "tokens=* usebackq" %%F IN (`"%DiskuvOCamlHome%\tools\apps\dkml-findup.exe",-f,%~dp0,.dkmlroot`) DO (
SET "DKMLDIR=%%F"
)
if not exist "%DKMLDIR%\.dkmlroot" (
	echo.
	echo.The '.dkmlroot' file was not found. Make sure you have run
	echo.the script 'installtime\windows\install-world.ps1' once.
	echo.
	exit /b 1
)

REM Find dune-project in an ancestor of DKMLDIR so we know where the Makefile is.
REM We do _not_ set TOPDIR which is used by most Diskuv OCaml scripts through _common_tool.sh, etc.
REM because the same scripts will autodetect TOPDIR if it is not set. And the developer
REM should be able to set their own TOPDIR to create their own switches, etc.
FOR /F "tokens=* usebackq" %%F IN (`"%DiskuvOCamlHome%\tools\apps\dkml-findup.exe",-f,%DKMLDIR%\..,dune-project`) DO (
SET "DKMAKE_TOPDIR=%%F"
)
if not exist "%DKMAKE_TOPDIR%\dune-project" (
	echo.
	echo.The 'dune-project' file was not found. Make sure you are running
	echo.this %~dp0\makeit.cmd script as a subdirectory / git submodule of
	echo.your local project.
	echo.
	exit /b 1
)

REM Find cygpath so we can convert Windows paths to Unix/Cygwin paths
if not defined DKMAKE_INTERNAL_CYGPATH (
	set "DKMAKE_INTERNAL_CYGPATH=%DiskuvOCamlMSYS2Dir%\usr\bin\cygpath.exe"
)

"%DKMAKE_INTERNAL_CYGPATH%" --version >NUL 2>NUL
if %ERRORLEVEL% neq 0 (
	echo.
	echo.The 'cygpath' command was not found. Make sure you have run
	echo.the script 'installtime\windows\install-world.ps1' once.
	echo.
	exit /b 1
)

REM Set DKMAKE_INTERNAL_DISKUVOCAMLHOME to something like /c/Users/user/AppData/Local/Programs/DiskuvOCaml/1/
FOR /F "tokens=* usebackq" %%F IN (`%%DKMAKE_INTERNAL_CYGPATH%% -au "%DiskuvOCamlHome%"`) DO (
SET "DKMAKE_INTERNAL_DISKUVOCAMLHOME=%%F"
)
SET DKMAKE_INTERNAL_DISKUVOCAMLHOME=%DKMAKE_INTERNAL_DISKUVOCAMLHOME:"=%

REM Find Powershell so we can add its directory to the PATH
FOR /F "tokens=* usebackq" %%F IN (`where.exe powershell.exe`) DO (
SET "DKMAKE_INTERNAL_POWERSHELLEXE=%%F"
)

"%DKMAKE_INTERNAL_POWERSHELLEXE%" -NoLogo -Help >NUL 2>NUL
if %ERRORLEVEL% neq 0 (
	echo.
	echo.The 'powershell.exe' command was not found. Make sure you have
	echo.PowerShell installed.
	echo.
	exit /b 1
)

REM Find Git so we can add its directory to the PATH
FOR /F "tokens=* usebackq" %%F IN (`where.exe git.exe`) DO (
SET "DKMAKE_INTERNAL_GITEXE=%%F"
)

"%DKMAKE_INTERNAL_GITEXE%" --version >NUL 2>NUL
if %ERRORLEVEL% neq 0 (
	echo.
	echo.The 'git.exe' command was not found. Make sure you have
	echo.Git for Windows installed.
	echo.
	exit /b 1
)

REM Set DKMAKE_INTERNAL_WINPATH to something like /c/WINDOWS/System32:/c/WINDOWS:/c/WINDOWS/System32/Wbem
FOR /F "tokens=* usebackq" %%F IN (`%%DKMAKE_INTERNAL_CYGPATH%% --path "%SYSTEMROOT%\System32;%SYSTEMROOT%;%SYSTEMROOT%\System32\Wbem"`) DO (
SET "DKMAKE_INTERNAL_WINPATH=%%F"
)
SET DKMAKE_INTERNAL_WINPATH=%DKMAKE_INTERNAL_WINPATH:"=%

REM Set DKMAKE_INTERNAL_POWERSHELLPATH to something like /c/WINDOWS/System32/WindowsPowerShell/v1.0/
FOR /F "tokens=* usebackq" %%F IN (`%%DKMAKE_INTERNAL_CYGPATH%% -au "%DKMAKE_INTERNAL_POWERSHELLEXE%\.."`) DO (
SET "DKMAKE_INTERNAL_POWERSHELLPATH=%%F"
)
SET DKMAKE_INTERNAL_POWERSHELLPATH=%DKMAKE_INTERNAL_POWERSHELLPATH:"=%

REM Set DKMAKE_INTERNAL_GITPATH to something like /c/Program Files/Git/cmd/
FOR /F "tokens=* usebackq" %%F IN (`%%DKMAKE_INTERNAL_CYGPATH%% -au "%DKMAKE_INTERNAL_GITEXE%\.."`) DO (
SET "DKMAKE_INTERNAL_GITPATH=%%F"
)
SET DKMAKE_INTERNAL_GITPATH=%DKMAKE_INTERNAL_GITPATH:"=%

REM Set DKMAKE_INTERNAL_MAKE
REM We set MSYSTEM=MSYS environment variable to mimic the msys2.exe launcher https://www.msys2.org/wiki/MSYS2-introduction/
if not defined DKMAKE_INTERNAL_MAKE (
	SET DKMAKE_INTERNAL_MAKE=%DiskuvOCamlMSYS2Dir%\usr\bin\env.exe ^
		MSYSTEM=MSYS ^
		MSYSTEM_CARCH=x86_64 ^
		MSYSTEM_CHOST=x86_64-pc-msys ^
		"PATH=%DKMAKE_INTERNAL_DISKUVOCAMLHOME%/bin:%DKMAKE_INTERNAL_DISKUVOCAMLHOME%/tools/ninja:%DKMAKE_INTERNAL_DISKUVOCAMLHOME%/tools/cmake/bin:%DKMAKE_INTERNAL_DISKUVOCAMLHOME%/tools/apps:%DKMAKE_INTERNAL_GITPATH%:/usr/bin:/bin:%DKMAKE_INTERNAL_WINPATH%:%DKMAKE_INTERNAL_POWERSHELLPATH%" ^
		make
)

%DKMAKE_INTERNAL_MAKE% --version >NUL 2>NUL
if %ERRORLEVEL% neq 0 (
	echo.
	echo.The 'make' command was not found. Make sure you have run
	echo.the command 'installtime\windows\install-world.ps1' once.
	echo.
	exit /b 1
)

REM Clear environment variables that will pollute the Makefile environment, especially for a clean environment in `./makeit shell`
set DKMAKE_INTERNAL_DOCH_PARENT=
set DKMAKE_INTERNAL_CYGPATH=
set DKMAKE_INTERNAL_DISKUVOCAMLHOME=
set DKMAKE_INTERNAL_WINPATH=
set DKMAKE_INTERNAL_POWERSHELLEXE=
set DKMAKE_INTERNAL_POWERSHELLPATH=
set DKMAKE_INTERNAL_GITEXE=
set DKMAKE_INTERNAL_GITPATH=

PUSHD "%DKMAKE_TOPDIR%"
%DKMAKE_INTERNAL_MAKE% "DKMAKE_CALLING_DIR=%DKMAKE_CALLING_DIR%" %*
POPD
goto end

:end
