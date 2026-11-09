#Requires -Version 5.1
<#
.SYNOPSIS
Writes a one-byte-patched copy of MFG Unlocker V1.7.0 that no longer turns an
already-selected RTX 40 GPU into "family=conflict" when Community Shaders hands
Streamline a D3D11 device.

.DESCRIPTION
Skyrim SE is a D3D11 game. Community Shaders calls slSetD3DDevice with its
ID3D11Device. MFG Unlocker V1.6.1 and V1.7.0 hook that call and pass the device
to gpu_dispatch::ObserveD3D12Device. QueryInterface(ID3D12Device) fails, the
LUID stays 0, and Publish(Unknown, 0) turns the existing Ada selection into
Family::eConflict. From then on every D3D12 NGX Evaluate of the DLSS SR feature
returns kRejected (NVSDK_NGX_Result_FAIL_FeatureNotSupported = 0xBAD00001):
the world is black and only the UI is drawn.

In the release DLL, gpu_dispatch::Publish starts at RVA 0x4C6A0 with
Selection::Observe inlined:

    0x4C6CD  48 85 D2   test rdx, rdx        ; luid == 0 ?
    0x4C6D0  74 3E      je   0x4C710         ; -> family = conflict (if known)

The patch changes the jump target to 0x4C71F, the shared "return false" tail,
so a device without a D3D12 LUID is ignored instead of poisoning the selection.
Every other path (different LUID, different family) still reports a conflict.

The script refuses any input other than the published V1.7.0 DLL, verifies the
surrounding bytes, never modifies the input and never overwrites an existing file.
#>
param(
    [Parameter(Mandatory = $true)][string] $InputPath,
    [Parameter(Mandatory = $true)][string] $OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedInput = 'e6b6e6b70a6ed3af839c9647a32fc22660ae6b2d655062c5c072246c91fc10c7'
$expectedOutput = '175caa1c61ba09a1c0970a6d98bb636bb12119a5d25661f26003e77faf6efc48'
$rva = 0x4C6D0
$context = [byte[]](0x48, 0x85, 0xD2, 0x74, 0x3E, 0x41, 0x83, 0xF8, 0x03, 0x74, 0x3D)
$contextStart = 3   # bytes of context before the patched jump

function Get-Sha256Hex([byte[]] $Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (-join ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') })) }
    finally { $sha.Dispose() }
}

$inputFull = [IO.Path]::GetFullPath($InputPath)
$outputFull = [IO.Path]::GetFullPath($OutputPath)
if ($inputFull -eq $outputFull) { throw 'OutputPath must differ from InputPath.' }
if (Test-Path -LiteralPath $outputFull) { throw "Refusing to overwrite $outputFull" }

$bytes = [IO.File]::ReadAllBytes($inputFull)
if ((Get-Sha256Hex $bytes) -ne $expectedInput) {
    throw 'Input is not the published MFGUnlocker.dll V1.7.0 (FileVersion 1.7.0.1145).'
}

# Map the RVA to a file offset through the PE section table.
$peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
$sectionCount = [BitConverter]::ToUInt16($bytes, $peOffset + 6)
$optionalSize = [BitConverter]::ToUInt16($bytes, $peOffset + 20)
$table = $peOffset + 24 + $optionalSize
$fileOffset = -1
for ($i = 0; $i -lt $sectionCount; $i++) {
    $entry = $table + 40 * $i
    $virtualSize = [BitConverter]::ToUInt32($bytes, $entry + 8)
    $virtualAddress = [BitConverter]::ToUInt32($bytes, $entry + 12)
    $rawSize = [BitConverter]::ToUInt32($bytes, $entry + 16)
    $rawPointer = [BitConverter]::ToUInt32($bytes, $entry + 20)
    $span = [Math]::Max($virtualSize, $rawSize)
    if ($rva -ge $virtualAddress -and $rva -lt ($virtualAddress + $span)) {
        $fileOffset = [int]($rva - $virtualAddress + $rawPointer)
        break
    }
}
if ($fileOffset -lt 0) { throw 'Patch RVA is outside every section.' }

for ($i = 0; $i -lt $context.Length; $i++) {
    if ($bytes[$fileOffset - $contextStart + $i] -ne $context[$i]) {
        throw "Unexpected bytes near RVA 0x$($rva.ToString('X')); not patching."
    }
}

$bytes[$fileOffset + 1] = 0x4D   # je 0x4C710 -> je 0x4C71F
if ((Get-Sha256Hex $bytes) -ne $expectedOutput) { throw 'Patched result has an unexpected hash.' }
[IO.File]::WriteAllBytes($outputFull, $bytes)
[pscustomobject]@{
    Output = $outputFull
    FileOffset = '0x{0:X}' -f $fileOffset
    Sha256 = $expectedOutput
}
