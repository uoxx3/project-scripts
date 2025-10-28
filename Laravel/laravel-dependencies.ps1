# --------------------------------------
# - Functions
# --------------------------------------

function Show-Header {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Header,
        [Parameter(Mandatory = $false, Position = 2)]
        [System.ConsoleColor] $ForegroundColor = [System.ConsoleColor]::White,
        [Parameter(Mandatory = $false, Position = 3)]
        [int] $NewLinesStart = 1,
        [Parameter(Mandatory = $false, Position = 4)]
        [int] $NewLinesEnd = 1,
        [Parameter(Mandatory = $false, Position = 5)]
        [int] $SeparatorMargin = 10,
        [Parameter(Mandatory = $false, Position = 6)]
        [string] $Separator = '═'
    )

    # Header configurations
    $newLinChar          = "`n"
    $headerSeparatorSize = $Header.Length + $SeparatorMargin + ($Separator.Length * 2) + 2 # Separator start + Separator end + Space * 2
    $headerSeparator     = $Separator * $headerSeparatorSize

    # Generate centered content
    $availableWidth     = $headerSeparatorSize - ($Separator.Length * 2) - 4
    $spacesNeeded       = $availableWidth - $Header.Length
    $startSpacesContent = [math]::Floor($spacesNeeded / 2)
    $endSpacesContent   = [math]::Ceiling($spacesNeeded / 2)
    $headerContent      = @(
        $Separator, 
        (" " * $startSpacesContent),
        $Header,
        (" " * $endSpacesContent),
        $Separator
    ) -join " "

    $headerContentArray       = @(
        $headerSeparator,
        $headerContent,
        $headerSeparator
    )

    # New lines at start
    if ($NewLinesStart -gt 0) {
        $lines = $newLinChar * $NewLinesStart
        Write-Host $lines -NoNewline
    }

    # Display the header
    foreach ($item in $headerContentArray) {
        Write-Host $item -ForegroundColor $ForegroundColor
    }

    # New lines at end
    if ($NewLinesEnd -gt 0) {
        $lines = $newLinChar * $NewLinesEnd
        Write-Host $lines -NoNewline
    }
}

function Test-AdminTerminal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Terminal,
        [Parameter(Mandatory = $true, Position = 2)]
        [string] $Script,
        [Parameter(Mandatory = $false, Position = 3)]
        [System.Security.Principal.WindowsIdentity] $User = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    )

    # Extract the current identity from current powershell
    # instance
    $principal     = New-Object System.Security.Principal.WindowsPrincipal($User)
    $isAdminStatus = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdminStatus) {
        return # Only break the funcion flow
    }

    # Display message
    Show-Header -Header "Restarting script as administrator" -ForegroundColor Red -NewLinesEnd 2

    # Execute the current script with administrator privileges
    $scriptArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$Script`""
    )
    
    try {
        $processInfo                 = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName        = $Terminal
        $processInfo.Arguments       = $scriptArgs
        $processInfo.Verb            = "RunAs"
        $processInfo.UseShellExecute = $true

        # Execute process
        [System.Diagnostics.Process]::Start($processInfo) | Out-Null

        # Finish current script
        exit(0)
    } catch [System.ComponentModel.Win32Exception] {
        # User reject the UAC
        $errorCode = $_.Exception.NativeErrorCode
        if ($errorCode -eq 1223) {
            Write-Host "Operation cancelled by the user.`n" -ForegroundColor Yellow
            exit(0)
        }

        throw # Launch other exceptions
    }

    exit(0)
}

function Test-Scoop {
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if ($null -eq $scoop) {
        Show-Header -Header "Installing scoop" -ForegroundColor Blue
        # Install scoop from web method
        Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
        # Retry to get scoop command
        $scoop = Get-Command $scoop -ErrorAction Stop
    }

    # Install scoop basic elements
    & $scoop install 7zip git

    # Add scoop buckets
    $bucketUrls = @{
        'main'     = 'https://github.com/ScoopInstaller/Main';
        'versions' = 'https://github.com/ScoopInstaller/Versions';
        'php'      = 'https://github.com/ScoopInstaller/PHP';
        'extras'   = 'https://github.com/ScoopInstaller/Extras';
    }

    foreach ($bucket in $bucketUrls.GetEnumerator()) {
        & $scoop bucket add $bucket.Key $bucket.Value
    }

    # Update scoop repositories
    & $scoop update

    # Install all scoop programs
    $programs = [System.Collections.ArrayList]@(
        'vcredist2022'
        'php84'
        'composer'
        'mariadb'
        'nodejs'
        'bun'
        'apache'
        'gh'
        'winscp'
        'sqlitebrowser'
        'heidisql'
        'postman'
        'sublime-text'
        'notepadplusplus'
        'vscode'
    )
    $programsInstall = $programs.Clone()
    $programsUpdate  = [System.Collections.ArrayList]@()

    
    # Check if any of programs already installed
    $enumerator = $programs.GetEnumerator()
    $installed  = & $scoop list

    while ($enumerator.MoveNext()) {
        $item  = $enumerator.Current
        $found = $installed | Select-String -Pattern $item

        if ($found) {
            $programsUpdate.Add($item)
            $programsInstall.Remove($item)
        }
    }
    
    if ($programsInstall.Count -gt 0) {
        & $scoop install @programsInstall
    }

    if ($programsUpdate.Count -gt 0) {
        & $scoop update @programsUpdate
    }

    # Clean programs and cache
    & $scoop cleanup *
    & $scoop cache rm *

    Clear-Host
}

function Update-PHPIniSettings {
    # Get php php.ini path
    $userPath             = [System.Environment]::GetFolderPath("UserProfile")
    $phpIniUUID           = (New-Guid).ToString('N')
    $phpIniSettings       = [System.IO.Path]::Combine($userPath, "scoop\persist\php84\cli\php.ini")
    $phpIniSettingsBackup = [System.IO.Path]::Combine($userPath, "scoop\persist\php84\cli\php-${phpIniUUID}.ini")

    # Extract settings from php.ini file
    $phpSettings        = Get-Content -Path $phpIniSettings -Encoding UTF8
    $phpSettingsChanges = @(
        @{
            Pattern = "^;?max_execution_time\s*=\s*\d+";
            Value   = "max_execution_time=90"
        },
        @{
            Pattern = "^;?extension\s*=\s*(curl|fileinfo|gd|gettext|intl|mbstring|exif|mysqli|openssl|pdo_mysql|pdo_pgsql|pdo_sqlite|pgsql|sockets|sodium|sqlite3|xsl|zip)";
            Replace = "extension=`$1"
        }
    )

    # Generate new php.ini content
    $phpNewSettings = @()
    foreach($line in $phpSettings) {
        $outLine = $line

        # Iterate every change
        foreach($change in $phpSettingsChanges) {
            # Ignore not matches lines
            if ($line -notmatch $change.Pattern) {
                continue
            }

            # Generate new content depending of key
            if ($change.ContainsKey('Value')) {
                $outLine = $change.Value
            } elseif ($change.ContainsKey('Replace')) {
                $outLine = $line -replace $change.Pattern, $change.Replace
            }

            break
        }

        # Attach the content to new settings
        $phpNewSettings += $outLine
    }

    # Create backup file
    Show-Header "Generating php.ini settings & backup" -ForegroundColor Green
    
    Copy-Item -Path $phpIniSettings -Destination $phpIniSettingsBackup -Force
    $phpNewSettings | Set-Content -Path $phpIniSettings -Encoding UTF8

    # Display information
    Write-Host "PHP settings - $phpIniSettings" -ForegroundColor Yellow
    Write-Host "PHP backup   - $phpIniSettingsBackup`n" -ForegroundColor Yellow
}

function Update-Mariadb {
    & myqld --install MariaDB
}

function Update-Composer {
    $environment = @(
        @{
            Key     = "COMPOSER_PROCESS_TIMEOUT";
            Value   = "1200";
            Context = "Machine";
        }
    )
    
    foreach($entry in $environment) {
        Write-Host $entry
        # [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, $entry.Context)
    }
}

# --------------------------------------
# - Default execution
# --------------------------------------

# Terminal information and other information
# about the current context
$currentTerminal = (Get-Process -Id $PID).Path
$currentScript   = $MyInvocation.MyCommand.Path


# Check if current script is running as administrator
Test-AdminTerminal -Terminal $currentTerminal -Script $currentScript

# Install scoop dependencies
Test-Scoop

# Update composer, mariadb, etc
Update-Composer
Update-Mariadb

# Update php.ini settings
Update-PHPIniSettings

# Wait to exit
Read-Host "Press enter to exit..."