# Start-LogoffUsersRestartServer
# attempts to log off all users, and then Restarts server

param(
    #minutes to wait after logoff attempt
    [int]$minutes = 8
)

#region functions
function Get-Quser {
    switch -Regex (quser) {
        '^\s?username' {
            continue
        }
        '^(\s|>)(?<UserName>\w+)\s*(?<SessionName>rdp[^\s]*)?\s*(?<ID>\d*)\s*(?<STATE>[^\s]*)\s*(?<IdleTime>[^\s]*)\s*(?<LogonTime>.+)' {
            Select-Object -InputObject ([pscustomobject]$Matches)  UserName, SessionName, ID, State, IdleTime, LogonTime
        }
    }
}

Function Disconnect-Users {
    param(
        [PSCustomObject[]]$id
    )

    $logoffCMDpath = Join-Path -Path $ENV:windir -ChildPath 'System32\logoff.exe'
    $logoffCMDObj = Get-Item -Path $logoffCMDpath
    Set-Alias -Name 'Start-Logoff' -Value $logoffCMDObj

    foreach ($logon in $id) {
        $notExecUser = -not $logon.ExecutingUser
        $logonID = $logon.ID.ToString()
        if ($notExecUser) {
            Start-Logoff $logonID
        }
    }
}

function Start-ServerReboot {
    # uses shutdown.exe for backwards compatibility
    # powershell's Restart-Computer may trigger 'unknown shutdown' 
    # warnings on older servers after reboot
    $splat = @{
        FilePath     = Join-Path -Path $env:windir -ChildPath 'System32\shutdown.exe'
        ArgumentList = '/r /t 1 /d p:1:1 /c "Scheduled Restart"'
    }
    Start-Process @splat
}

#endregion functions

$userLogons = Get-Quser

$userLogons | ForEach-Object {
    Disconnect-Users -ids $_.id
}

if ($userLogons) {
    do {
        Start-Sleep -Seconds 15
        $userLogons = Get-Quser
    }
    while ( $userLogons -and (get-date) -lt (Get-Date).AddMinutes($minutes) )
}

If ($userLogons) {
    Throw "User logons are still active after $minutes minutes"
}

Start-ServerReboot
