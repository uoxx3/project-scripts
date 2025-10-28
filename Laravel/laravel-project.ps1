# --------------------------------------
# - Functions
# --------------------------------------

<#
.SYNOPSIS
    Displays a formatted header with customizable appearance and spacing.

.DESCRIPTION
    This function creates a visually appealing header with centered text, separator lines,
    and configurable colors and spacing. It's useful for creating section headers in scripts.

.PARAMETER Header
    The text to display in the header center.

.PARAMETER ForegroundColor
    The color of the header text and separators. Defaults to White.

.PARAMETER NewLinesStart
    Number of new lines to add before the header. Defaults to 1.

.PARAMETER NewLinesEnd
    Number of new lines to add after the header. Defaults to 1.

.PARAMETER SeparatorMargin
    The margin size around the header text for the separator line. Defaults to 10.

.PARAMETER Separator
    The character used for separator lines. Defaults to '═'.

.EXAMPLE
    Show-Header -Header "Installation Started" -ForegroundColor Green

.EXAMPLE
    Show-Header "Processing Complete" Cyan 2 1 5 '*'
#>
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

    $headerContentArray = @(
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

<#
.SYNOPSIS
    Checks if the Laravel installer is available and installs it if missing.

.DESCRIPTION
    This function verifies whether the Laravel installer Composer package is installed globally.
    If not found, it automatically installs the laravel/installer package using Composer.

.EXAMPLE
    Test-LaravelInstaller
#>
function Test-LaravelInstaller {
    Show-Header -Header "Checking Laravel Installer" -ForegroundColor Green

    # Check for laravel installer executable
    $installer        = Get-Command laravel -ErrorAction SilentlyContinue
    $installerPackage = "laravel/installer"

    if ($null -ne $installer) {
        Write-Host "Composer package `"$installerPackage`" already installed. Skip install.`n" -ForegroundColor Yellow
        return
    }

    # Install installer from composer
    Show-Header "Installing Composer `"$installerPackage`""
    & composer global require $installerPackage
}

<#
.SYNOPSIS
    Converts Windows-style file paths to Unix-style paths.

.DESCRIPTION
    Replaces backslashes (\) with forward slashes (/) in file paths, making them compatible
    with cross-platform applications and web URLs.

.PARAMETER Path
    The file path to convert.

.EXAMPLE
    Convert-PathToValid -Path "C:\Users\Project\file.txt"
    Returns: "C:/Users/Project/file.txt"

.EXAMPLE
    Convert-PathToValid ".\src\index.php"
    Returns: "./src/index.php"
#>
function Convert-PathToValid {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Path
    )

    return ($Path -replace "\\", "/")
}

<#
.SYNOPSIS
    Creates a new Laravel project with optional dependencies and configurations.

.DESCRIPTION
    This function creates a complete Laravel project using Composer, installs specified dependencies,
    runs Artisan commands, and manages the project setup process from start to finish.

.PARAMETER Path
    The directory path where the Laravel project will be created.

.PARAMETER PathRoot
    The root directory to return to after project creation.

.PARAMETER Dependencies
    Array of Composer packages to install as regular dependencies.

.PARAMETER DevDependencies
    Array of Composer packages to install as development dependencies.

.PARAMETER ArtisanCommands
    Array of Artisan commands to execute after project creation.

.EXAMPLE
    New-LaravelProject -Path "./myapp" -PathRoot "." -Dependencies @("inertiajs/inertia-laravel") -ArtisanCommands @("inertia:middleware")

.EXAMPLE
    New-LaravelProject "project" "." @("spatie/laravel-permission") @("barryvdh/laravel-debugbar") @("vendor:publish", "key:generate")
#>
function New-LaravelProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [string] $Path,
        [Parameter(Mandatory = $true, Position = 2)]
        [AllowEmptyString()]
        [string] $PathRoot,
        [Parameter(Mandatory = $false, Position = 3)]
        [string[]] $Dependencies = @(),
        [Parameter(Mandatory = $false, Position = 4)]
        [string[]] $DevDependencies = @(),
        [Parameter(Mandatory = $false, Position = 5)]
        [string[]] $ArtisanCommands = @()
    )

    # Project information
    $projectPath   = Convert-PathToValid $Path
    $projectExists = Test-Path -Path $Path

    # Check if the project location exists
    Show-Header "Creating Laravel Project `"$projectPath`"" -ForegroundColor Green
    if (-not($projectExists)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    # Generate project from composer
    $projectArgs = @(
        'create-project',
        'laravel/laravel',
        $projectPath
    )

    & composer @projectArgs

    # Install project dependencies
    Set-Location -Path $Path

    foreach($dependency in $Dependencies) {
        Show-Header "Installing Laravel dependency `"$dependency`"" -ForegroundColor Cyan
        & composer require $dependency
    }

    foreach($dependency in $DevDependencies) {
        Show-Header "Installing Laravel dev-dependency `"$dependency`"" -ForegroundColor Cyan
        & composer require --dev $dependency
    }

    # Execute artisan commands
    foreach($command in $ArtisanCommands) {
        $fullCommand = @('artisan') + $command

        Show-Header "Executing artisan command `"$fullCommand`"" -ForegroundColor Cyan
        & php @fullCommand
    }

    # Install bun dependencies
    Show-Header "Installing bun dependencies for `"$Path`"" -ForegroundColor Cyan
    & bun install

    # Return to project root
    Set-Location -Path $PathRoot
}

<#
.SYNOPSIS
    Creates a new Vue.js project using Bun package manager.

.DESCRIPTION
    This function creates a Vue.js project using Bun's create command, installs dependencies,
    and manages the project setup process with optional regular and development dependencies.

.PARAMETER Path
    The directory path where the Vue.js project will be created.

.PARAMETER PathRoot
    The root directory to return to after project creation.

.PARAMETER Dependencies
    Array of npm packages to install as regular dependencies.

.PARAMETER DevDependencies
    Array of npm packages to install as development dependencies.

.EXAMPLE
    New-VuejsProject -Path "./frontend" -PathRoot "." -Dependencies @("axios", "vue-router") -DevDependencies @("@vitejs/plugin-vue")

.EXAMPLE
    New-VuejsProject "vue-app" "." @("pinia", "vue-i18n") @("eslint", "prettier")
#>
function New-VuejsProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [string] $Path,
        [Parameter(Mandatory = $true, Position = 2)]
        [AllowEmptyString()]
        [string] $PathRoot,
        [Parameter(Mandatory = $false, Position = 3)]
        [string[]] $Dependencies = @(),
        [Parameter(Mandatory = $false, Position = 4)]
        [string[]] $DevDependencies = @()
    )

    # Project information
    $projectName   = Split-Path -Path $Path -Leaf
    $projectPath   = Convert-PathToValid $Path

    # Check if the project location exists
    Show-Header "Creating Vuejs Project `"$projectPath`"" -ForegroundColor Green

    # Generate project from composer
    Set-Location $PathRoot
    $projectArgs = @(
        'create',
        'vue@latest',
        $projectName
    )

    & bun @projectArgs

    # Install bun dependencies
    Set-Location -Path $Path
    Show-Header "Installing bun dependencies for `"$Path`"" -ForegroundColor Cyan
    & bun install

    # Install project dependencies
    foreach($dependency in $Dependencies) {
        Show-Header "Installing Vuejs dependency `"$dependency`"" -ForegroundColor Cyan
        & bun add $dependency
    }

    foreach($dependency in $DevDependencies) {
        Show-Header "Installing Vuejs dev-dependency `"$dependency`"" -ForegroundColor Cyan
        & bun add -d $dependency
    }

    # Return to project root
    Set-Location -Path $PathRoot
}

# --------------------------------------
# - Default execution
# --------------------------------------

$projectAsk = Read-Host -Prompt "Enter the project name or path"
if ($projectAsk.Trim().Length -eq 0) {
    $projectAsk = "./"
}

# Sub-projects directories
$projectDir       = [System.IO.Path]::GetFullPath($projectAsk)
$apiProjectDir    = [System.IO.Path]::Combine($projectDir, "project-api")
$webappProjectDir = [System.IO.Path]::Combine($projectDir, "project-webapp")

# Generate Laravel project
$newLaravelProjectArgs = @{
    Path            = $apiProjectDir;
    PathRoot        = $projectDir;
    Dependencies    = @(
        "laravel/sanctum"
    );
    DevDependencies = @(
        "jetbrains/phpstorm-attributes",
        "phpunit/phpunit"
    );
    ArtisanCommands = @(
        @("install:broadcasting"),
        @("install:api")
    )
}
New-LaravelProject @newLaravelProjectArgs

# Generate Vuejs project
$newVuejsProjectArgs = @{
    Path             = $webappProjectDir;
    PathRoot         = $projectDir;
    Dependencies     = @(
        '@primeuix/themes',
        '@primevue/forms',
        '@tailwindcss/vite',
        'axios',
        'primeicons',
        'primevue',
        'tailwindcss',
        'tailwindcss-primeui',
        'uuid',
        'zod'
    );
    DevDependencies  = @(
        '@tsconfig/node22',
        '@types/seedrandom',
        '@types/jsdom',
        '@types/node',
        '@vue/tsconfig',
        'vite-plugin-vue-devtools',
        'sass',
        'sass-loader',
        'laravel-echo',
        'pusher-js'
    )
}
New-VuejsProject @newVuejsProjectArgs

# Finish process
Show-Header "Execution Finished Successfully" -ForegroundColor Green
Read-Host "Press enter to finish..."