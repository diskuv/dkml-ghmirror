# ================================
# UnixInvokers.psm1
#
# PowerShell Module to invoke a Cygwin or a MSYS2 command.
#

$ErrorActionPreference = "Stop"
$InvokerTailRefreshSeconds = 0.25
$InvokerTailLines = 1
Export-ModuleMember -Variable InvokerTailLines
Export-ModuleMember -Variable InvokerTailRefreshSeconds

function Invoke-CygwinCommand {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification='Unread $handle is a fix to a Powershell bug')]
    param (
        [Parameter(Mandatory=$true)]
        $Command,
        [Parameter(Mandatory=$true)]
        $CygwinDir,
        $RedirectStandardOutput,
        $RedirectStandardError,
        $TailFunction
    )
    $arglist = @("-l",
        "-c",
        ('" { ' + ($Command -replace '"', '\"') + '; } 2>&1 "'))
    if ($RedirectStandardOutput -and $RedirectStandardError) {
        $proc = Start-Process -NoNewWindow -FilePath $CygwinDir\bin\bash.exe -PassThru `
            -RedirectStandardOutput $RedirectStandardOutput `
            -RedirectStandardError $RedirectStandardError `
            -ArgumentList $arglist
    } else {
        $proc = Start-Process -NoNewWindow -FilePath $CygwinDir\bin\bash.exe -PassThru `
            -ArgumentList $arglist
    }
    $handle = $proc.Handle # cache proc.Handle https://stackoverflow.com/a/23797762/1479211
    while (-not $proc.HasExited) {
        if ($RedirectStandardOutput -and $TailFunction) {
            $tail = Get-Content -Path $RedirectStandardOutput -Tail $InvokerTailLines
            Invoke-Command $TailFunction -ArgumentList @($tail)
        }
        Start-Sleep -Seconds $InvokerTailRefreshSeconds
    }
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    if ($exitCode -ne 0) {
        Write-Error "Cygwin command failed! Exited with $exitCode. Command was: $Command"
        throw
    }
}
Export-ModuleMember -Function Invoke-CygwinCommand

function Invoke-MSYS2Command {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification='Unread $handle is a fix to a Powershell bug')]
    param (
        [Parameter(Mandatory=$true)]
        $Command,
        [Parameter(Mandatory=$true)]
        $MSYS2Dir,
        $RedirectStandardOutput,
        $RedirectStandardError,
        $TailFunction,
        [switch]
        $IgnoreErrors
    )
    # Note: We use the same environment variable settings as make.cmd
    $arglist = @("MSYSTEM=MSYS",
        "HOME=/home/$env:USERNAME",
        "$MSYS2Dir\usr\bin\bash.exe",
        "-c",
        ('"' +
        "export PATH=/usr/local/bin:/usr/bin:/bin:/opt/bin:" +
        '\"$PATH\"' +
        "; { " +
        ($Command -replace '"', '\"') +
        '; } 2>&1 "'))
    if ($RedirectStandardOutput) {
        $proc = Start-Process -NoNewWindow -FilePath $MSYS2Dir\usr\bin\env.exe -PassThru `
            -RedirectStandardOutput $RedirectStandardOutput `
            -RedirectStandardError $RedirectStandardError `
            -ArgumentList $arglist
    } else {
        $proc = Start-Process -NoNewWindow -FilePath $MSYS2Dir\usr\bin\env.exe -PassThru `
            -ArgumentList $arglist
    }
    $handle = $proc.Handle # cache proc.Handle https://stackoverflow.com/a/23797762/1479211
    while (-not $proc.HasExited) {
        if ($RedirectStandardOutput -and $TailFunction) {
            $tail = Get-Content -Path $RedirectStandardOutput -Tail $InvokerTailLines
            Invoke-Command $TailFunction -ArgumentList @($tail)
        }
        Start-Sleep -Seconds $InvokerTailRefreshSeconds
    }
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    if (!$IgnoreErrors -and $exitCode -ne 0) {
        Write-Error "MSYS2 command failed! Exited with $exitCode. Command was: $Command"
        throw
    }
}
Export-ModuleMember -Function Invoke-MSYS2Command
