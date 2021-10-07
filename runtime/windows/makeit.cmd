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
REM However, if a user installs Git for Windows with the full MinGW environment added to the PATH
REM or with Git Bash added to the PATH (GitHub Actions windows-2019 environment adds both of these!)
REM then we have to be extremely careful not to mix MinGW with our MSYS2 environment.
REM
REM Rules
REM -----
REM
REM 1. We look for git-gui.exe, which is unique to the \cmd subdirectory. If it exists we add that directory.
REM 2. Otherwise we just look for git.exe
REM
REM Context
REM -------
REM
REM     Directory: C:\Program Files\Git\bin
REM
REM Mode                 LastWriteTime         Length Name
REM ----                 -------------         ------ ----
REM -a---           8/24/2021 10:09 AM          45584 bash.exe
REM -a---           8/24/2021 10:09 AM          45072 git.exe
REM -a---           8/24/2021 10:09 AM          45584 sh.exe
REM
REM     Directory: C:\Program Files\Git\cmd
REM
REM Mode                 LastWriteTime         Length Name
REM ----                 -------------         ------ ----
REM -a---           8/24/2021 10:09 AM          45072 git.exe
REM -a---           8/24/2021 10:09 AM         136208 git-gui.exe
REM -a---           8/24/2021 10:09 AM         136208 gitk.exe
REM -a---           8/24/2021 10:09 AM          45072 git-lfs.exe
REM -a---           8/24/2021 10:09 AM           3022 start-ssh-agent.cmd
REM -a---           8/24/2021 10:09 AM           2723 start-ssh-pageant.cmd
REM
REM     Directory: C:\Program Files\Git\mingw64\bin
REM
REM Mode                 LastWriteTime         Length Name
REM ----                 -------------         ------ ----
REM -a---           8/24/2021 10:24 AM          90243 acountry.exe
REM -a---           8/24/2021 10:24 AM          58396 adig.exe
REM -a---           8/24/2021 10:24 AM          49530 ahost.exe
REM -a---           8/24/2021 10:24 AM         222709 antiword.exe
REM -a---           8/24/2021 10:24 AM          46077 blocked-file-util.exe
REM -a---           8/24/2021 10:24 AM         865942 brotli.exe
REM -a---           8/24/2021 10:24 AM          68276 bunzip2.exe
REM -a---           8/24/2021 10:24 AM          68276 bzcat.exe
REM -a---           8/24/2021 10:24 AM           2140 bzcmp
REM -a---           8/24/2021 10:24 AM           2140 bzdiff
REM -a---           8/24/2021 10:24 AM           2054 bzegrep
REM -a---           8/24/2021 10:24 AM           2054 bzfgrep
REM -a---           8/24/2021 10:24 AM           2054 bzgrep
REM -a---           8/24/2021 10:24 AM          68276 bzip2.exe
REM -a---           8/24/2021 10:24 AM          49031 bzip2recover.exe
REM -a---           8/24/2021 10:24 AM           1297 bzless
REM -a---           8/24/2021 10:24 AM           1297 bzmore
REM -a---           8/24/2021 10:24 AM          78548 connect.exe
REM -a---           8/24/2021 10:24 AM          98322 create-shortcut.exe
REM -a---           8/24/2021 10:24 AM         274076 curl.exe
REM -a---           8/24/2021 10:24 AM          54272 edit.dll
REM -a---           8/24/2021 10:24 AM          18432 edit_test.exe
REM -a---           8/24/2021 10:24 AM          20480 edit_test_dll.exe
REM -a---           8/24/2021 10:24 AM         117225 envsubst.exe
REM -a---           8/24/2021 10:24 AM         117111 gettext.exe
REM -a---           8/24/2021 10:24 AM           4629 gettext.sh
REM -a---           8/24/2021 10:24 AM          43807 gettextize
REM -a---           8/24/2021 10:09 AM        3502592 git.exe
REM -a---           8/24/2021 10:24 AM          45938 git-askpass.exe
REM -a---           8/24/2021 10:24 AM          19161 git-askyesno.exe
REM -a---           8/24/2021 10:24 AM          60662 git-credential-helper-selector.exe
REM -a---           8/24/2021 10:09 AM         402353 gitk
REM -a---           8/24/2021 10:24 AM       10126968 git-lfs.exe
REM -a---           8/24/2021 10:09 AM        3502592 git-receive-pack.exe
REM -a---           8/24/2021 10:24 AM           9878 git-update-git-for-windows
REM -a---           8/24/2021 10:09 AM        3502592 git-upload-archive.exe
REM -a---           8/24/2021 10:09 AM        3502592 git-upload-pack.exe
REM -a---           8/24/2021 10:24 AM            140 jemalloc.sh
REM -a---           8/24/2021 10:24 AM         179224 jeprof
REM -a---           8/24/2021 10:24 AM         142883 libbrotlicommon.dll
REM -a---           8/24/2021 10:24 AM          52362 libbrotlidec.dll
REM -a---           8/24/2021 10:24 AM          99146 libbz2-1.dll
REM -a---           8/24/2021 10:24 AM         123855 libcares-4.dll
REM -a---           8/24/2021 10:24 AM        2783388 libcrypto-1_1-x64.dll
REM -a---           8/24/2021 10:24 AM         673948 libcurl-4.dll
REM -a---           8/24/2021 10:24 AM         202568 libexpat-1.dll
REM -a---           8/24/2021 10:24 AM          82097 libgcc_s_seh-1.dll
REM -a---           8/24/2021 10:24 AM         509898 libgmp-10.dll
REM -a---           8/24/2021 10:24 AM         275300 libhogweed-6.dll
REM -a---           8/24/2021 10:24 AM        1058528 libiconv-2.dll
REM -a---           8/24/2021 10:24 AM         170241 libidn2-0.dll
REM -a---           8/24/2021 10:24 AM         133659 libintl-8.dll
REM -a---           8/24/2021 10:24 AM          77904 libjansson-4.dll
REM -a---           8/24/2021 10:24 AM         529915 libjemalloc.dll
REM -a---           8/24/2021 10:24 AM         153747 liblzma-5.dll
REM -a---           8/24/2021 10:24 AM         289910 libnettle-8.dll
REM -a---           8/24/2021 10:24 AM         184406 libnghttp2-14.dll
REM -a---           8/24/2021 10:24 AM         281695 libpcre-1.dll
REM -a---           8/24/2021 10:24 AM         618344 libpcre2-8-0.dll
REM -a---           8/24/2021 10:24 AM          41752 libpcreposix-0.dll
REM -a---           8/24/2021 10:24 AM         263986 libssh2-1.dll
REM -a---           8/24/2021 10:24 AM         560796 libssl-1_1-x64.dll
REM -a---           8/24/2021 10:24 AM          43429 libssp-0.dll
REM -a---           8/24/2021 10:24 AM        1745041 libstdc++-6.dll
REM -a---           8/24/2021 10:24 AM          92313 libtre-5.dll
REM -a---           8/24/2021 10:24 AM        1764460 libunistring-2.dll
REM -a---           8/24/2021 10:24 AM          59645 libwinpthread-1.dll
REM -a---           8/24/2021 10:24 AM        1358585 libxml2-2.dll
REM -a---           8/24/2021 10:24 AM         999818 libzstd.dll
REM -a---           8/24/2021 10:24 AM          53283 lzmadec.exe
REM -a---           8/24/2021 10:24 AM          28069 lzmainfo.exe
REM -a---           8/24/2021 10:24 AM          62834 odt2txt.exe
REM -a---           8/24/2021 10:24 AM         715420 openssl.exe
REM -a---           8/24/2021 10:24 AM           2177 pcre2-config
REM -a---           8/24/2021 10:24 AM        1537966 pdftotext.exe
REM -a---           8/24/2021 10:24 AM          57152 pkcs1-conv.exe
REM -a---           8/24/2021 10:24 AM          44973 proxy-lookup.exe
REM -a---           8/24/2021 10:24 AM          62989 sexp-conv.exe
REM -a---           8/24/2021 10:24 AM          30392 sqlite3_analyzer.sh
REM -a---           8/24/2021 10:24 AM        1679679 tcl86.dll
REM -a---           8/24/2021 10:24 AM          79654 tclsh.exe
REM -a---           8/24/2021 10:24 AM          79654 tclsh86.exe
REM -a---           8/24/2021 10:24 AM        1505405 tk86.dll
REM -a---           8/24/2021 10:24 AM          82962 unxz.exe
REM -a---           8/24/2021 10:24 AM           1082 update-ca-trust
REM -a---           8/24/2021 10:24 AM         106724 WhoUses.exe
REM -a---           8/24/2021 10:24 AM         319640 wintoast.exe
REM -a---           8/24/2021 10:24 AM          66707 wish.exe
REM -a---           8/24/2021 10:24 AM          66707 wish86.exe
REM -a---           8/24/2021 10:24 AM          36022 x86_64-w64-mingw32-agrep.exe
REM -a---           8/24/2021 10:24 AM          64688 x86_64-w64-mingw32-deflatehd.exe
REM -a---           8/24/2021 10:24 AM          60246 x86_64-w64-mingw32-inflatehd.exe
REM -a---           8/24/2021 10:24 AM           1835 xml2-config
REM -a---           8/24/2021 10:24 AM          52901 xmlcatalog.exe
REM -a---           8/24/2021 10:24 AM         131824 xmllint.exe
REM -a---           8/24/2021 10:24 AM          81407 xmlwf.exe
REM -a---           8/24/2021 10:24 AM          82962 xz.exe
REM -a---           8/24/2021 10:24 AM          82962 xzcat.exe
REM -a---           8/24/2021 10:24 AM           6633 xzcmp
REM -a---           8/24/2021 10:24 AM          53284 xzdec.exe
REM -a---           8/24/2021 10:24 AM           6633 xzdiff
REM -a---           8/24/2021 10:24 AM           5630 xzegrep
REM -a---           8/24/2021 10:24 AM           5630 xzfgrep
REM -a---           8/24/2021 10:24 AM           5630 xzgrep
REM -a---           8/24/2021 10:24 AM           1799 xzless
REM -a---           8/24/2021 10:24 AM           2162 xzmore
REM -a---           8/24/2021 10:24 AM         139084 zipcmp.exe
REM -a---           8/24/2021 10:24 AM         136075 zipmerge.exe
REM -a---           8/24/2021 10:24 AM         162733 ziptool.exe
REM -a---           8/24/2021 10:24 AM         116428 zlib1.dll
REM
REM Logic replicated in installtime\windows\setup-userprofile.ps1
SET DKMAKE_INTERNAL_GITEXE=
FOR /F "tokens=* usebackq" %%F IN (`where.exe git-gui.exe`) DO (
SET "DKMAKE_INTERNAL_GITEXE=%%F"
)
REM If we have git-gui.exe we can't test it out with --version since it only will popup a dialog box
IF defined DKMAKE_INTERNAL_GITEXE GOTO HaveGit

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

:HaveGit
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
