#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert([bool] $Condition, [string] $Message) {
    if (!$Condition) { throw "Assertion failed: $Message" }
}

function Assert-Throws([scriptblock] $Action, [string] $Message) {
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert $threw $Message
}

$root = Split-Path -Parent $PSScriptRoot
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$testName = 'skyrim-guide-test-' + [guid]::NewGuid().ToString('N')
$temp = Join-Path $tempBase $testName
[IO.Directory]::CreateDirectory($temp) | Out-Null
$encoding = New-Object System.Text.UTF8Encoding($false)
try {
    Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter '*.ps1' | ForEach-Object {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref] $tokens, [ref] $errors) | Out-Null
        Assert ($errors.Count -eq 0) "PowerShell parses: $($_.Name)"
    }

    $manifest = Get-Content -LiteralPath (Join-Path $root 'versions.json') -Raw | ConvertFrom-Json
    foreach ($entry in @($manifest.downloads) + @($manifest.files)) {
        Assert ($entry.sha256 -cmatch '^[a-f0-9]{64}$') 'Valid lowercase SHA256 fingerprint'
    }
    $evidence = Get-Content -LiteralPath (Join-Path $root 'evidence\session-summary.json') -Raw | ConvertFrom-Json
    Assert ($evidence.status.appliedMultiplier -eq 3) 'Historical evidence records 3X'

    $mod = Join-Path $temp ('Mods [test]\Upscaling ' + [char]0x6D4B)
    $streamline = Join-Path $mod 'Shaders\Upscaling\Streamline'
    [IO.Directory]::CreateDirectory($streamline) | Out-Null
    $logs = Join-Path $temp 'logs'
    [IO.Directory]::CreateDirectory($logs) | Out-Null
    $generator = Join-Path $root 'scripts\New-Config.ps1'
    foreach ($mode in @('NeuralOnly', 'NativeMfg')) {
        $output = Join-Path $temp $mode
        & $generator -UpscalingMod $mod -LogDirectory $logs -OutputDirectory $output -Mode $mode | Out-Null
        $ini = [IO.File]::ReadAllText((Join-Path $output 'OptiScaler.ini'))
        Assert (!$ini.Contains('{{')) "$mode resolves every placeholder"
        Assert ($ini.Contains("NvngxDlssPath=$streamline")) "$mode preserves literal Unicode paths"
        Assert ($ini.Contains('FGNvngxReplacement=None')) "$mode has no replacement engine"
        Assert ($ini.Contains('Dx11Upscaler=dlss_12')) "$mode uses the DX12 bridge"
        Assert ($ini.Contains('ApplyModel=true')) "$mode applies the model"
        Assert (Test-Path -LiteralPath (Join-Path $output 'OptiScaler_preload.txt')) 'Marker generated'
        if ($mode -eq 'NativeMfg') {
            Assert ($ini.Contains('FGInput=upscaler')) 'MFG has upscaler inputs'
            Assert ($ini.Contains('FGOutput=dlssg')) 'MFG selects NVIDIA'
            Assert ($ini.Contains('LoadAsiPlugins=true')) 'MFG loads the unlock core'
            Assert ($ini.Contains('InterpolationCount=2')) 'MFG requests two generated frames'
        }
        else {
            Assert ($ini.Contains('FGInput=nofg')) 'NR-only disables FG input'
            Assert ($ini.Contains('FGOutput=nofg')) 'NR-only disables FG output'
            Assert ($ini.Contains('LoadAsiPlugins=false')) 'NR-only disables the unlock core'
        }
        $hashBefore = (Get-FileHash -LiteralPath (Join-Path $output 'OptiScaler.ini')).Hash
        Assert-Throws {
            & $generator -UpscalingMod $mod -LogDirectory $logs -OutputDirectory $output -Mode $mode
        } 'Existing configurations are not overwritten'
        Assert ((Get-FileHash -LiteralPath (Join-Path $output 'OptiScaler.ini')).Hash -eq $hashBefore) 'No overwrite'
    }
    Assert-Throws {
        & $generator -UpscalingMod $mod -LogDirectory $logs -OutputDirectory (Join-Path $mod 'SKSE\Plugins')
    } 'Generator rejects direct installation'
    Assert-Throws {
        & $generator -UpscalingMod 'relative\Upscaling' -LogDirectory $logs -OutputDirectory (Join-Path $temp 'bad')
    } 'Generator rejects relative paths'
    Assert-Throws {
        & $generator -UpscalingMod ($mod + "`nFGOutput=ffx") -LogDirectory $logs -OutputDirectory (Join-Path $temp 'bad')
    } 'Generator rejects INI path injection'

    $statusFile = Join-Path $temp 'status.json'
    $reader = Join-Path $root 'scripts\Read-MfgStatus.ps1'
    $state = [ordered]@{
        pid = 0
        heartbeat = 1788619219
        bridgeReady = $true
        gameFrameGenerationOn = $true
        setOptionsAccepted = $true
        getStateResult = 0
        appliedMultiplier = 3
        actualFramesPresented = 3
        dlssgStatus = 0
        midpointReadyAtFirstCreate = $true
        backportReadyAtCreate = $true
        restartRequired = $false
        streamlineRebuildRequired = $false
        pipelineMayPredateDetour = $false
        universalRouteFailure = 0
        activeProviderPath = 'C:\Example\Data\SKSE\Plugins\OptiScaler\streamline\nvngx_dlssg.dll'
        activeProviderVersionMajor = 310
        activeProviderVersionMinor = 7
        activeProviderVersionBuild = 0
        intervalValidSamples = 100
        intervalInvalidSamples = 0
        intervalLastCount = 2
        realFpsMilli = 37800
        dlssFpsMilli = 113399
        stateSampleAgeMs = 31
        fpsSampleAgeMs = 0
    }
    function Save-Fixture {
        [IO.File]::WriteAllText($statusFile, ($state | ConvertTo-Json), $encoding)
    }
    Save-Fixture
    $result = & $reader -StatusPath $statusFile -Historical
    Assert ($result.Verdict -eq 'HistoricalOnly') 'Archive cannot be live proof'
    Assert ($result.TelemetryConsistent -and !$result.IsLive) 'Consistent archived telemetry is labelled'
    $state.activeProviderPath = 'C:\' + [char]0x6D4B + '\Data\SKSE\Plugins\OptiScaler\streamline\nvngx_dlssg.dll'
    Save-Fixture
    $result = & $reader -StatusPath $statusFile -Historical
    Assert ($result.Provider -eq $state.activeProviderPath) 'UTF-8 status paths are preserved'
    $result = & $reader -StatusPath $statusFile
    Assert ($result.Verdict -eq 'StaleOrWrongProcess') 'Old heartbeat and absent game are rejected'
    $state.heartbeat = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $state.pid = $PID
    Save-Fixture
    $result = & $reader -StatusPath $statusFile
    Assert (!$result.IsLive) 'A live PowerShell PID is not a live Skyrim PID'
    $state.actualFramesPresented = 1
    Save-Fixture
    $result = & $reader -StatusPath $statusFile -Historical
    Assert (!$result.TelemetryConsistent) 'Checked Active is not proof of generated frames'
    $state.actualFramesPresented = 3
    $state.midpointReadyAtFirstCreate = $false
    Save-Fixture
    Assert (!(& $reader -StatusPath $statusFile -Historical).TelemetryConsistent) 'Missing Ada correction fails'
    $state.midpointReadyAtFirstCreate = $true
    $state.activeProviderPath = 'C:\Example\dlssg_to_fsr3.dll'
    Save-Fixture
    Assert (!(& $reader -StatusPath $statusFile -Historical).TelemetryConsistent) 'Replacement provider fails'
    $state.bridgeReady = 'false'
    Save-Fixture
    Assert-Throws { & $reader -StatusPath $statusFile -Historical } 'String booleans do not pass'
    $state.Remove('bridgeReady')
    Save-Fixture
    Assert-Throws { & $reader -StatusPath $statusFile -Historical } 'Incomplete status fails closed'

    Write-Output "PASS: generator, pinned hashes, evidence, and status-reader smoke tests (PowerShell $($PSVersionTable.PSVersion))."
}
finally {
    $resolved = [IO.Path]::GetFullPath($temp)
    if (!$resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -ne $testName) {
        throw 'Refusing cleanup outside the test temporary directory.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
