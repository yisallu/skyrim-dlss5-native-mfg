#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $StatusPath,

    [ValidateRange(2, 6)]
    [int] $ExpectedMultiplier = 3,

    [ValidateRange(1, 120)]
    [int] $MaximumAgeSeconds = 10,

    [switch] $Historical
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$item = Get-Item -LiteralPath $StatusPath -ErrorAction Stop
# A live writer may be replacing the JSON. Retry a short partial read, not a bad schema.
$state = $null
for ($attempt = 0; $attempt -lt 3; $attempt++) {
    try {
        $state = Get-Content -LiteralPath $item.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        break
    }
    catch {
        if ($attempt -eq 2) { throw }
        Start-Sleep -Milliseconds 100
    }
}
$required = @(
    'pid', 'heartbeat', 'bridgeReady', 'gameFrameGenerationOn',
    'appliedMultiplier', 'actualFramesPresented', 'dlssgStatus',
    'setOptionsAccepted', 'getStateResult', 'midpointReadyAtFirstCreate',
    'backportReadyAtCreate', 'restartRequired', 'streamlineRebuildRequired',
    'pipelineMayPredateDetour', 'universalRouteFailure',
    'activeProviderPath', 'activeProviderVersionMajor',
    'activeProviderVersionMinor', 'activeProviderVersionBuild',
    'intervalValidSamples', 'intervalInvalidSamples', 'intervalLastCount',
    'realFpsMilli', 'dlssFpsMilli', 'stateSampleAgeMs', 'fpsSampleAgeMs'
)
foreach ($name in $required) {
    if ($null -eq $state.PSObject.Properties[$name]) {
        throw "Missing status field '$name'. Use the pinned v1.2 schema or review this script."
    }
}
$booleanFields = @(
    'bridgeReady', 'gameFrameGenerationOn', 'setOptionsAccepted',
    'midpointReadyAtFirstCreate', 'backportReadyAtCreate',
    'restartRequired', 'streamlineRebuildRequired', 'pipelineMayPredateDetour'
)
foreach ($name in $booleanFields) {
    if ($state.$name -isnot [bool]) { throw "Status field '$name' must be a JSON boolean." }
}
foreach ($name in ($required | Where-Object {
    $_ -notin $booleanFields -and $_ -ne 'activeProviderPath'
})) {
    $value = $state.$name
    if ($null -eq $value -or $value -is [string] -or $value -is [bool] -or
        $value -isnot [ValueType] -or [double] $value -ne [math]::Truncate([double] $value)) {
        throw "Status field '$name' must be an integer."
    }
}
if ($state.activeProviderPath -isnot [string]) {
    throw 'activeProviderPath must be a string.'
}

$sampleTime = [DateTimeOffset]::FromUnixTimeSeconds([long] $state.heartbeat)
$age = ([DateTimeOffset]::UtcNow - $sampleTime).TotalSeconds
$process = Get-Process -Id ([int] $state.pid) -ErrorAction SilentlyContinue
$sameProcess = $false
if ($null -ne $process -and $process.ProcessName -eq 'SkyrimSE') {
    $sameProcess = $process.StartTime.ToUniversalTime() -le $sampleTime.UtcDateTime
}
$fresh = $age -ge -2 -and $age -le $MaximumAgeSeconds
$live = !$Historical -and $sameProcess -and $fresh

$reasons = New-Object 'System.Collections.Generic.List[string]'
if (!$state.bridgeReady) { $reasons.Add('bridge-not-ready') }
if (!$state.gameFrameGenerationOn) { $reasons.Add('fg-off') }
if (!$state.setOptionsAccepted -or $state.getStateResult -ne 0) {
    $reasons.Add('streamline-call-not-accepted')
}
if ($state.appliedMultiplier -ne $ExpectedMultiplier) { $reasons.Add('wrong-applied-multiplier') }
if ($state.actualFramesPresented -lt $ExpectedMultiplier) { $reasons.Add('insufficient-presented-frames') }
if ($state.dlssgStatus -ne 0) { $reasons.Add('dlssg-runtime-status-not-ok') }
if (!$state.midpointReadyAtFirstCreate -or !$state.backportReadyAtCreate) {
    $reasons.Add('ada-correction-not-ready-at-create')
}
if ($state.restartRequired -or $state.streamlineRebuildRequired -or $state.pipelineMayPredateDetour) {
    $reasons.Add('pipeline-needs-restart-or-rebuild')
}
if ($state.universalRouteFailure -ne 0) { $reasons.Add('unlock-route-failed') }
if ($state.activeProviderPath -notmatch '(?i)[\\/]OptiScaler[\\/]streamline[\\/]nvngx_dlssg\.dll$' -or
    $state.activeProviderVersionMajor -ne 310 -or
    $state.activeProviderVersionMinor -ne 7 -or $state.activeProviderVersionBuild -ne 0) {
    $reasons.Add('provider-does-not-match-tested-layout-and-version')
}
if ($state.intervalValidSamples -le 0 -or $state.intervalInvalidSamples -ne 0 -or
    $state.intervalLastCount -ne ($ExpectedMultiplier - 1)) {
    $reasons.Add('temporal-requests-do-not-match')
}
if ($state.stateSampleAgeMs -lt 0 -or $state.stateSampleAgeMs -gt ($MaximumAgeSeconds * 1000)) {
    $reasons.Add('state-sample-too-old')
}
$telemetryActive = $reasons.Count -eq 0
if ($Historical) {
    $verdict = 'HistoricalOnly'
}
elseif (!$live) {
    $verdict = 'StaleOrWrongProcess'
}
elseif (!$telemetryActive) {
    $verdict = 'NotConfirmed'
}
else {
    $verdict = 'LiveTelemetryConsistent'
}

[pscustomobject]@{
    Verdict = $verdict
    IsLive = [bool] $live
    TelemetryConsistent = $telemetryActive
    ProcessId = $state.pid
    SampleTime = $sampleTime
    AgeSeconds = [math]::Round($age, 1)
    AppliedMultiplier = $state.appliedMultiplier
    FramesPresentedSinceQuery = $state.actualFramesPresented
    DlssgStatus = $state.dlssgStatus
    TemporalSamples = $state.intervalValidSamples
    BaseFpsReported = $state.realFpsMilli / 1000.0
    OutputFpsReportedOrEstimated = $state.dlssFpsMilli / 1000.0
    FpsSampleAgeMs = $state.fpsSampleAgeMs
    Provider = $state.activeProviderPath
    Reasons = @($reasons.ToArray())
    Limit = 'Telemetry only: independently verify provider hash/signature, NR dispatch, and image quality.'
}
