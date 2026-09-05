#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $UpscalingMod,

    [Parameter(Mandatory)]
    [string] $LogDirectory,

    [Parameter(Mandatory)]
    [string] $OutputDirectory,

    [ValidateSet('NeuralOnly', 'NativeMfg')]
    [string] $Mode = 'NeuralOnly'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-AbsoluteLocalPath([string] $Value) {
    if ($Value -notmatch '^[A-Za-z]:[\\/]' -or $Value -match '[\r\n{}]') {
        throw "Use an absolute local Windows path without newlines or template braces: $Value"
    }
    return [IO.Path]::GetFullPath($Value)
}

$mod = Get-AbsoluteLocalPath $UpscalingMod
$logs = Get-AbsoluteLocalPath $LogDirectory
$output = Get-AbsoluteLocalPath $OutputDirectory
$modPrefix = $mod.TrimEnd('\') + '\'
if ($output.TrimEnd('\').Equals($mod.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($modPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Generate into a staging directory outside the mod, then install manually after review.'
}
$gameStreamline = Join-Path $mod 'Shaders\Upscaling\Streamline'
if (!(Test-Path -LiteralPath $gameStreamline -PathType Container)) {
    throw 'Upscaling mod not found. Expected Shaders\Upscaling\Streamline in the supplied mod.'
}
if (!(Test-Path -LiteralPath $logs -PathType Container)) {
    throw 'Create the log directory first. The generator does not create game or log directories.'
}

$root = Split-Path -Parent $PSScriptRoot
$ini = Join-Path $output 'OptiScaler.ini'
$marker = Join-Path $output 'OptiScaler_preload.txt'
if ((Test-Path -LiteralPath $ini) -or (Test-Path -LiteralPath $marker)) {
    throw 'Output files already exist. Use a new output directory; nothing will be overwritten.'
}

$companions = Join-Path $mod 'SKSE\Plugins\OptiScaler'
$isMfg = $Mode -eq 'NativeMfg'
$values = [ordered]@{
    MODE = $Mode
    FG_ENABLED = $(if ($isMfg) { 'true' } else { 'false' })
    FG_INPUT = $(if ($isMfg) { 'upscaler' } else { 'nofg' })
    FG_OUTPUT = $(if ($isMfg) { 'dlssg' } else { 'nofg' })
    LOAD_ASI = $(if ($isMfg) { 'true' } else { 'false' })
    COMPANIONS = $companions
    GAME_STREAMLINE = $gameStreamline
    ASI_PLUGINS = Join-Path $companions 'plugins'
    LOG_FILE = Join-Path $logs 'OptiScaler.log'
}
$text = [IO.File]::ReadAllText((Join-Path $root 'configs\OptiScaler.ini.in'))
foreach ($key in $values.Keys) {
    $text = $text.Replace('{{' + $key + '}}', [string] $values[$key])
}
if ($text -match '\{\{[A-Z_]+\}\}') {
    throw 'Unresolved template value.'
}

if (!(Test-Path -LiteralPath $output)) {
    New-Item -ItemType Directory -Path $output | Out-Null
}
$encoding = New-Object System.Text.UTF8Encoding($false)
# CreateNew protects existing files even if another process writes after preflight.
$stream = [IO.File]::Open($ini, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
try {
    $bytes = $encoding.GetBytes($text)
    $stream.Write($bytes, 0, $bytes.Length)
}
finally {
    $stream.Dispose()
}
[IO.File]::Copy((Join-Path $root 'configs\OptiScaler_preload.txt'), $marker, $false)
Write-Output "Generated $Mode configuration: $ini"
Write-Output 'No game configuration was installed. Review the files and follow the guide.'
