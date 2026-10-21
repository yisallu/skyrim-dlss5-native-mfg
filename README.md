# 上古卷轴 5 SE：DLSS 5 神经渲染 + NVIDIA 原生 3X MFG

基于 **RTX 4070 + Community Shaders + MO2** 的一次实际运行记录，整理可供人和其他 AI 重现的安装方法。验证日期：**2026-09-05**。

这里的“DLSS 5”指 `OptiScaler_DLSSNR` 调用的 NVIDIA Neural Rendering 模型后处理；不是 Bethesda 或 NVIDIA 为 Skyrim 发布的官方集成。MFG 使用 NVIDIA 的 `nvngx_dlssg.dll`，**不是 DLSSG-to-FSR3、Arturs、Nukem 或 XeFG 替代方案**。4070 上的解锁、DX11 桥接和神经渲染组合都属于非官方实验配置。

**仓库仅包含教程、配置模板和检查脚本，不分发 NVIDIA 模型、驱动、游戏文件或第三方 DLL。**

English: This is a version-pinned, experimental Skyrim SE reproduction guide for DLSS Neural Rendering and NVIDIA-native 3X MFG on an RTX 4070. It is not an official DLSS 5 integration or an FSR frame-generation replacement. The model is a separate, user-supplied prerequisite.

- 给 AI 的操作协议：[AI_REPRODUCTION.md](AI_REPRODUCTION.md)
- 版本、下载地址、SHA256：[versions.json](versions.json)
- 问题排查：[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- 脱敏验证记录：[evidence/session-summary.json](evidence/session-summary.json)

2026-10-21 第一次换上 310.9.16 时世界全黑，只剩顶部界面。原因是默认预设落到了 Preset M（状态里的 `dlssSrGameHint=13`），而 Community Shaders 的 Streamline 仍是 2.10.3。修正是整套 Streamline DLSS 插件换成 2.14.16，并把 Community Shaders 的 `presetDLSS` 固定为 Preset K，OptiScaler 的 `RenderPresetForAll=11`。这次修正还没有新的实机帧数。

## 1. 已验证与未验证

本次运行同时观察到：

| 项目 | 记录 |
| --- | --- |
| 神经渲染 | 有持续的 `DlssNr_Dx12::Dispatch`，约 4.6 ms/渲染帧 |
| NR 模型分辨率 | 1280×800；游戏输出 2560×1600 |
| 原生 FG 提供者 | NVIDIA 签名有效的 `nvngx_dlssg.dll` 310.7.0 |
| 解锁器应用倍率 | `appliedMultiplier=3` |
| 呈现状态 | `actualFramesPresented=3`，`dlssgStatus=0` |
| Ada 时间位置修正 | `midpointReadyAtFirstCreate=true` |
| NGX 时间请求 | 两个插入位置：1/3、2/3 |
| 一次 FPS 采样 | 基础约 37.8；输出报告/估算约 113.4 |

`actualFramesPresented` 的严格含义是“自上次状态查询以来呈现的帧数”。它与已应用倍率、NGX 请求和原生提供者一起支持 3X 正在运行，**不是单凭一个计数证明每张输出图都正确**。

没有完成：最终画面的逐帧去重/间隔测量、端到端延迟测试、与 FSR 的画质对比、长时间稳定性测试。解锁器在缺少输出呈现回调时会估算输出 FPS，不能把该数字当作独立测速结果。“3X”也不代表输入延迟变成三分之一。

## 2. 实际使用的链路

```text
Skyrim SE 的 DX11 渲染
  -> Community Shaders Upscaling 提供 DLSS 输入
  -> OptiScaler 的 DX11 -> DX12 桥接，Dx11Upscaler=dlss_12
  -> DLSS 超分辨率 + DLSS-NR 模型处理
  -> OptiFG 从 upscaler 取得帧生成输入
  -> 独立的 Streamline 2.12.0 + NVIDIA DLSSG 310.7.0
  -> RTX40MFGCore 在进程内解锁并修正 Ada 时间位置
  -> 请求 2 张生成帧，加 1 张渲染帧，共 3X
```

Skyrim 本身没有原生 DLSS FG。只安装 MFG 解锁器没有用，**OptiScaler 的 DX12 帧生成桥接是本教程的重要部分**。

两套 Streamline 必须分开：

- `Shaders\Upscaling\Streamline`：保留 Upscaling 原有的 **2.10.3**，包括 `nvngx_dlss.dll`。
- `SKSE\Plugins\OptiScaler\streamline`：额外提供帧生成用的 **2.12.0**。

不要把后者覆盖到前者，也不要根据旧 README 中“仅 DX12 / 仅 RTX 50”的文字直接否定这条已记录的实验路径；同时不能因此推断所有 DX11 游戏都兼容。

## 3. 环境与前提

| 组件 | 实测版本/条件 |
| --- | --- |
| GPU | NVIDIA GeForce RTX 4070，12 GB |
| 驱动 | 616.64；NR 上游说明最低 616.56，但这里只实测前者 |
| 游戏 | `SkyrimSE.exe` **1.5.97.0** |
| SKSE | **2.0.20**，与上述运行时匹配 |
| Community Shaders | **1.8.0.0**，安装的 AIO 构建 |
| Upscaling | **1.4.0** |
| 原有 Streamline / DLSS SR | **2.10.3 / 310.5.2** |
| OptiScaler_DLSSNR | **v0.2.0-dlssnr**，界面构建号 `9918b95` |
| FG Streamline / DLSSG | **2.12.0 / 310.7.0** |
| RTX40MFG-Unlock | **v1.2**，Core 文件版本 1.2.0.22 |
| NR 模型 | **310.8.0**，用户提供的 Ada 兼容修改版 |
| 加载器 | 已正常工作的 `d3dx9_42.dll` SKSE 插件预加载器 |
| 管理器 | MO2，经当前实例的 SKSE 启动 |

前提：

1. 现有游戏、SKSE、Community Shaders 和 Upscaling 已能正常运行，并使用 DLSS 超分。
2. 查游戏 EXE 的文件版本，不根据“SE/AE”商品名称、MO2 默认配置名或旧说明猜运行时。此记录不能直接证明 AE 1.6.x 兼容。
3. 当前 `d3dx9_42.dll` 预加载器必须支持 `SKSE\Plugins\<名称>_preload.txt`。没有时先解决与运行时匹配的基础加载器，不覆盖已有代理 DLL。
4. 确认系统满足 DLSS FG 的 Windows/驱动/HAGS 条件。教程不会自动修改驱动、注册表或 Windows 安全设置。
5. 检查同一 MO2 实例的 **当前 profile**、左侧文件优先级和 `overwrite`。运行时通常以最高优先级文件为准。

### 必须单独准备的模型

`nvngx_dlssnr.dll` 不在 OptiScaler 发布包中。4070 需要适用于 Ada 的模型版本，不能把只支持 Blackwell 的原文件放进去就期待成功。

本记录使用的模型指纹：

```text
文件版本：310.8.0
文件大小：165840496 bytes
SHA256：CEB6432F6FBDF44D886014BCD47241932BF8B67439FEEF9BBDD0961436662650
```

这是**已使用文件的指纹，不是 NVIDIA 对修改版的真实性或安全性背书**。本仓库不提供模型、不提供模型破解/补丁工具，也不声称能从普通安装包自动得到相同文件。请自行合法取得、核实来源；没有时先停在前提检查阶段，不能宣称完整复现。

不要把它误命名成 `nvngx_dlss.dll` 或 `nvngx_dlssd.dll`。SR、Ray Reconstruction、Neural Rendering 是不同组件。

## 4. 下载来源

安装需要的三个归档：

1. [Dagherbou/OptiScaler_DLSSNR v0.2.0-dlssnr](https://github.com/Dagherbou/OptiScaler_DLSSNR/releases/tag/v0.2.0-dlssnr)：`OptiScaler-DLSSNR-v0.2.0.zip`。
2. [NVIDIA-RTX/Streamline v2.12.0](https://github.com/NVIDIA-RTX/Streamline/releases/tag/v2.12.0)：`streamline-sdk-v2.12.0.zip`。
3. [dashdogy/RTX40MFG-Unlock v1.2](https://github.com/dashdogy/RTX40MFG-Unlock/releases/tag/v1.2)：`Universal-RTX-40-MFG-Unlock-v1.2.zip`。

原始参考项目：[ShyVortex/dlss-unlocked](https://github.com/ShyVortex/dlss-unlocked) 与 [v0.2.0 发布页](https://github.com/ShyVortex/dlss-unlocked/releases/tag/v0.2.0-dlssnr)。其整合包包含 **DLSSG-to-FSR3**，所以此处改用 NR 上游包并明确选择 NVIDIA 原生 FG。不要运行该整合安装器，也不要把其完整目录直接覆盖到游戏。

不要使用浮动的 `latest` 代替固定版本。SHA256 用于固定输入，不替代来源和许可证检查。Community Shaders、Upscaling、SKSE 仍由各自正规渠道提供；本仓库不是整合包。

## 5. 准备路径与备份

以下命令在 **Windows PowerShell 5.1 或 PowerShell 7** 中执行，以本仓库为当前目录。路径全部是示例，**必须先替换成实际路径**。

```powershell
$ErrorActionPreference = 'Stop'
$G = 'D:\Games\Skyrim Special Edition'  # 实际游戏根目录
$M = 'D:\MO2\SkyrimSE'                 # 实际 MO2 实例目录，不是 MO2.exe 所在目录
$U = Join-Path $M 'mods\Upscaling'     # 实际提供 Upscaling 文件的 mod
$P = Join-Path $U 'SKSE\Plugins'
$C = Join-Path $P 'OptiScaler'
$W = Join-Path $M ('scratch\dlss5-mfg-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))

if (Get-Process -Name SkyrimSE -ErrorAction SilentlyContinue) {
    throw '先保存并正常退出游戏，不要强制结束有未保存进度的进程。'
}
if (!(Test-Path -LiteralPath (Join-Path $G 'SkyrimSE.exe'))) { throw '游戏路径错误' }
if (!(Test-Path -LiteralPath (Join-Path $U 'Shaders\Upscaling\Streamline'))) { throw 'Upscaling 路径错误' }

New-Item -ItemType Directory -Path $W | Out-Null
New-Item -ItemType Directory -Path (Join-Path $W 'backup') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $W 'logs') | Out-Null
if (Test-Path -LiteralPath $P) {
    Copy-Item -LiteralPath $P -Destination (Join-Path $W 'backup\Plugins') -Recurse
}
```

还应备份当前生效的 `SettingsUser.json`、profile 的 `modlist.txt`，记录初始文件清单。备份只放在本机，不能提交到本仓库。

在 MO2 的 Data 视图确认以下文件的来源，尤其检查 `overwrite` 是否有同名文件：

```text
SKSE\Plugins\OptiScaler.ini
SKSE\Plugins\OptiScaler.dll
SKSE\Plugins\CommunityShaders\SettingsUser.json
```

如果已有其他 OptiScaler、`dxgi.dll`、`version.dll`、`dinput8.dll`、ReShade 或帧生成替代器，先查清加载关系。**不要覆盖或删除不属于本次安装的文件。** 以下首次部署命令假设 `$P` 中还没有 OptiScaler；已有时停止，按差异合并，不能套用首次部署命令。

### 下载并校验，不执行安装器

```powershell
$manifest = Get-Content -LiteralPath .\versions.json -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($asset in $manifest.downloads) {
    $archive = Join-Path $W $asset.name
    $extract = Join-Path $W $asset.id
    if ((Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $extract)) {
        throw '下载/解压目标已存在，请使用新的暂存目录。'
    }
    Invoke-WebRequest -UseBasicParsing -Uri $asset.url -OutFile $archive
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $asset.sha256) {
        throw "归档校验失败：$($asset.name)"
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $extract
}
$NR = Join-Path $W 'optiscaler-nr'
$SDK = Join-Path $W 'streamline'
$Unlock = Join-Path $W 'native-mfg'
```

若上游重新打包导致指纹不同，停止并调查，不跳过校验。本配方**不运行** `setup_windows.bat`、签名覆盖 `.reg` 或自动驱动更新。

## 6. 第一阶段：只启用 DLSS-NR

### 6.1 文件布局

```text
mods\Upscaling\
  Shaders\Upscaling\Streamline\        原有文件不动
    nvngx_dlss.dll                    310.5.2
    sl.*.dll                         2.10.3
  SKSE\Plugins\
    OptiScaler.dll
    OptiScaler.ini
    OptiScaler_preload.txt
    OptiScaler\
      D3D12_OptiScaler\D3D12Core.dll
      amd_fidelityfx_*.dll            上游伴随库，存在不代表启用 FSR FG
      libxess*.dll / libxell.dll      上游伴随库
      Licenses\
      DLSSNR\
        nvngx.dll_dlssnr.dll          forwarder，不是模型
        nvngx_dlssnr.dll              用户单独提供的模型
```

首次部署：

```powershell
foreach ($name in @('OptiScaler.dll', 'OptiScaler.ini', 'OptiScaler_preload.txt', 'OptiScaler')) {
    if (Test-Path -LiteralPath (Join-Path $P $name)) { throw "已有 $name，先核对而非覆盖。" }
}
if (!(Test-Path -LiteralPath $P)) { New-Item -ItemType Directory -Path $P | Out-Null }
Copy-Item -LiteralPath (Join-Path $NR 'OptiScaler.dll') -Destination $P
Copy-Item -LiteralPath (Join-Path $NR 'OptiScaler') -Destination $P -Recurse
Copy-Item -LiteralPath (Join-Path $NR 'Licenses') -Destination $C -Recurse
Copy-Item -LiteralPath (Join-Path $NR 'READ ME - DLSS Neural Rendering.txt') -Destination $C
New-Item -ItemType Directory -Path (Join-Path $C 'DLSSNR') | Out-Null
Copy-Item -LiteralPath (Join-Path $NR 'nvngx.dll_dlssnr.dll') -Destination (Join-Path $C 'DLSSNR')

$ModelPath = 'C:\YourModel\nvngx_dlssnr.dll'  # 必须修改
$modelExpected = ($manifest.files | Where-Object { $_.path -like '*/nvngx_dlssnr.dll' }).sha256
if ((Get-FileHash -LiteralPath $ModelPath -Algorithm SHA256).Hash -ne $modelExpected) {
    throw '模型不等于实测输入；核对来源和兼容性后，作为单独实验记录，不能冒充精确复现。'
}
Copy-Item -LiteralPath $ModelPath -Destination (Join-Path $C 'DLSSNR\nvngx_dlssnr.dll')
```

伴随库保留上游原样并保留许可证。**不要因为文件名里出现 AMD/FSR 就删掉它们**；以当前配置和实际 FG 提供者区分使用路线。

### 6.2 生成两套配置

脚本只生成到暂存目录，不会安装到 mod，也不会覆盖已有输出。

```powershell
$nrConfig = Join-Path $W 'configs\nr-only'
$mfgConfig = Join-Path $W 'configs\native-mfg'
.\scripts\New-Config.ps1 -UpscalingMod $U -LogDirectory (Join-Path $W 'logs') -OutputDirectory $nrConfig -Mode NeuralOnly
.\scripts\New-Config.ps1 -UpscalingMod $U -LogDirectory (Join-Path $W 'logs') -OutputDirectory $mfgConfig -Mode NativeMfg

Copy-Item -LiteralPath (Join-Path $nrConfig 'OptiScaler.ini') -Destination $P
Copy-Item -LiteralPath (Join-Path $nrConfig 'OptiScaler_preload.txt') -Destination $P
```

模板使用实际 mod 的绝对路径解决 MO2 虚拟文件系统下的查找问题。移动 MO2 实例后要重新生成，不能照搬别人的盘符。

NR-only 的关键值：

```ini
[Upscalers]
Dx11Upscaler=dlss_12
Dx12Upscaler=dlss
[FrameGen]
Enabled=false
FGInput=nofg
FGOutput=nofg
FGNvngxReplacement=None
[Plugins]
LoadAsiPlugins=false
[DlssNr]
Enabled=true
ApplyModel=true
WorkingScale=0.5
ReversibleMode=3
AutoCapture=false
```

`ReversibleMode=3` 是 Hybrid proxy + composed。`WorkingScale=0.5` 是 NR 模型宽、高各为输出的一半，**不是 DLSS 超分质量档位**。

### 6.3 启用 CS Upscaling，关闭它自带的帧生成

本机最初存在这个隐藏问题：MO2 左侧勾选了 Upscaling，但 `SettingsUser.json` 的 `"Disable at Boot": {"Upscaling": true}` 禁止了它启动。

先通过 MO2 确认正在生效的用户设置文件。通常可能在：

```text
<MO2实例>\overwrite\SKSE\Plugins\CommunityShaders\SettingsUser.json
```

如果没有用户设置文件，先启动原有 CS，保存一次设置，再退出。不把下面的局部字段当作完整配置文件覆盖过去。

本版本需达到：

```json
{
  "Disable at Boot": { "Upscaling": false },
  "Upscaling": {
    "upscaleMethod": 3,
    "qualityMode": 2,
    "frameGenerationMode": 0
  }
}
```

这几个数值仅对应本次 **Upscaling 1.4.0** 的 DLSS、Balanced、关闭自带 FG。其他版本优先通过 UI 确认语义，不盲套枚举值。

可按以下方式仅改相关属性，并保留其他设置：

```powershell
$SettingsPath = Join-Path $M 'overwrite\SKSE\Plugins\CommunityShaders\SettingsUser.json' # 以实际获胜文件为准
if (Get-Process -Name SkyrimSE -ErrorAction SilentlyContinue) { throw '先正常退出游戏。' }
Copy-Item -LiteralPath $SettingsPath -Destination (Join-Path $W 'backup\SettingsUser.json')
$cs = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($null -eq $cs.'Disable at Boot' -or $null -eq $cs.Upscaling) { throw '设置结构不匹配，停止。' }
$cs.'Disable at Boot'.Upscaling = $false
$cs.Upscaling.upscaleMethod = 3
$cs.Upscaling.qualityMode = 2
$cs.Upscaling.frameGenerationMode = 0
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($SettingsPath, ($cs | ConvertTo-Json -Depth 100), $utf8)
```

### 6.4 重启验证 NR，再进入第二阶段

1. 从正确的 MO2 实例启动 **SKSE**，进入可移动的实际场景。
2. `d3dx9_42.log` 应记录发现 `OptiScaler` 并加载成功；若当前预加载器不写这个日志，使用它自己的等价诊断。
3. `CommunityShaders.log` 应加载 Upscaling。默认日志目录是系统“文档”下的 `My Games\Skyrim Special Edition\SKSE`，注意文档可能重定向到 OneDrive。
4. 按 **Insert** 打开 OptiScaler。界面应是 `DLSS w/Dx12`，Neural Rendering 为绿色 `Running`，且 `Apply the model` 已勾选。
5. 新一轮 `OptiScaler.log` 必须有实际 `DlssNr_Dx12::Dispatch` 和模型耗时，不能只看到“发现 DLL”就算完成。
6. 保存这套已验证的 NR-only INI 和本轮日志。失败时先解决 NR，不继续叠加 MFG。

界面顶部显示 `DLSS 310.5.2` 是正常的：这是超分 DLL 版本，不是 NR 模型版本。

## 7. 第二阶段：加入 NVIDIA 原生 MFG

**先保存并退出游戏。不能在进程仍加载 DLL 时替换文件。**

### 7.1 安装独立的 FG Streamline

从 SDK 的 **`bin\x64` 发布目录**取文件，不用 `development` 目录。

```powershell
if (Get-Process -Name SkyrimSE -ErrorAction SilentlyContinue) { throw '先正常退出游戏。' }
$slTarget = Join-Path $C 'streamline'
if (Test-Path -LiteralPath $slTarget) { throw 'FG Streamline 目录已存在，先核对。' }
New-Item -ItemType Directory -Path $slTarget | Out-Null
foreach ($name in @('sl.interposer.dll','sl.common.dll','sl.dlss_g.dll','sl.reflex.dll','sl.pcl.dll','nvngx_dlssg.dll')) {
    Copy-Item -LiteralPath (Join-Path $SDK "bin\x64\$name") -Destination $slTarget
}
Copy-Item -LiteralPath (Join-Path $SDK 'license.txt') -Destination $slTarget
Copy-Item -LiteralPath (Join-Path $SDK 'bin\x64\reflex.license.txt') -Destination $slTarget

$sig = Get-AuthenticodeSignature -LiteralPath (Join-Path $slTarget 'nvngx_dlssg.dll')
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'NVIDIA') {
    throw 'NVIDIA FG 提供者签名异常，停止。'
}
```

### 7.2 通过 OptiScaler 加载解锁 Core

**这是本机验证过的特定加载方式，不是上游 UAL + ReShade 通用安装法。**

仅将 `RTX40MFGCore.dll` 复制并改名为 `RTX40MFGCore.asi`：

```powershell
$plugins = Join-Path $C 'plugins'
if (Test-Path -LiteralPath $plugins) { throw '已有 ASI 插件目录，先检查是否会重复加载。' }
New-Item -ItemType Directory -Path $plugins | Out-Null
Copy-Item -LiteralPath (Join-Path $Unlock 'RTX40MFGCore.dll') -Destination (Join-Path $plugins 'RTX40MFGCore.asi')
$licenseTarget = Join-Path $C 'Licenses\RTX40MFG-Unlock'
New-Item -ItemType Directory -Path $licenseTarget | Out-Null
foreach ($name in @('LICENSE','MINHOOK-LICENSE.txt','README.md','SHA256SUMS.txt')) {
    Copy-Item -LiteralPath (Join-Path $Unlock $name) -Destination $licenseTarget
}
```

原理：v1.2 Core 自身在 `DllMain` 初始化；OptiScaler ASI 加载器可提前加载它。Core 默认 Follow game，倍率由 OptiScaler 请求。**不能假设后续版本仍兼容此改名方式。**

本配方不安装 `RTX40MFG.asi`、`RTX40MFG-UI.addon64`、UAL、ReShade，也不添加游戏根目录代理 DLL。不要同时加载 Core 的两个副本。

检查游戏根目录是否已有 `RTX40MFG-Universal.json`：旧配置可能覆盖 Follow game。若存在先备份、审查，不盲删；本次验证使用默认 Follow game。Core 自动产生的 `.status.json` 是诊断输出，不是手工安装的插件。

### 7.3 切到 NativeMfg 配置

确认 MO2 `overwrite` 或更高优先级 mod 没有另一个 `OptiScaler.ini`，然后：

```powershell
Copy-Item -LiteralPath (Join-Path $P 'OptiScaler.ini') -Destination (Join-Path $W 'backup\OptiScaler-NR-verified.ini')
Copy-Item -LiteralPath (Join-Path $mfgConfig 'OptiScaler.ini') -Destination (Join-Path $P 'OptiScaler.ini') -Force
```

主要变化：

```ini
[FrameGen]
Enabled=true
FGInput=upscaler
FGOutput=dlssg
FGNvngxReplacement=None
[DLSSG]
InterpolationCount=2
UseGamesReflexMarkers=false
[Plugins]
LoadAsiPlugins=true
```

`InterpolationCount=2` 意味着 **2 张生成帧 + 1 张渲染帧 = 3X**。不是把它设成 3。

保留模板里的 `Dxgi=false`、`StreamlineSpoofing=false`、`UseFakenvapi=false`、`EarlyHooking=true` 和 DLSS-only 输入设置。`DisableFlipMetering=true` 是实测配置中的值，不是对所有显卡/游戏的推荐；未针对它做单独 A/B。

别打开 `Force Dynamic MFG`，也不从首轮 3X 测试直接跳到 5X/6X。菜单中的 `None (Real DLSSG)` 才是本教程需要的提供者选择。

### 7.4 检查关键文件指纹

```powershell
foreach ($entry in $manifest.files) {
    $file = Join-Path $U ($entry.path.Replace('/', '\'))
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    if ($actual -ne $entry.sha256) { throw "文件与配方不一致：$($entry.path)" }
}
```

这检查的是物理 mod 文件。仍需用 MO2 的 Data 视图和运行日志确认它们是当前生效的文件，而不是被更高优先级文件覆盖。

## 8. 如何确认真的运行，而非只勾选开关

经 MO2/SKSE **重新启动**，进入实际场景，等初始化完成。检查：

```text
<日志目录>\OptiScaler.log
<游戏根目录>\RTX40MFG-Universal.status.json
%TEMP%\MfgUnlock-<本轮Skyrim进程PID>.log
%TEMP%\MfgUnlock-intervals-<本轮Skyrim进程PID>.csv
```

状态脚本只读文件和进程信息，不注入游戏、不改任何配置：

```powershell
$statusPath = Join-Path $G 'RTX40MFG-Universal.status.json'
$first = .\scripts\Read-MfgStatus.ps1 -StatusPath $statusPath
Start-Sleep -Seconds 2
$second = .\scripts\Read-MfgStatus.ps1 -StatusPath $statusPath
$second | Format-List
if (!$second.IsLive -or !$second.TelemetryConsistent) { throw '当前运行尚未得到一致的成功证据。' }
if ($second.TemporalSamples -le $first.TemporalSamples) { throw '采样未增加；回到活动场景后再检查。' }
```

合格的运行状态应接近：

```text
Verdict                  LiveTelemetryConsistent
AppliedMultiplier        3
FramesPresentedSinceQuery 3
DlssgStatus               0
```

同时人工确认：

1. `activeProviderPath` 指向本配方的 `OptiScaler\streamline\nvngx_dlssg.dll`，版本 310.7.0，与签名/哈希核对一致。
2. `midpointReadyAtFirstCreate`、`backportReadyAtCreate` 为 true，`restartRequired` 为 false。
3. 本轮 NR 日志仍持续 Dispatch。MFG 成功不能替代 NR 验证，反之亦然。
4. CSV 中 `count=2`，请求位置交替为 1/3 和 2/3。CSV 的 `submitDeltaUs` 是 CPU 调用间隔，**不是最终显示帧间隔**。
5. 转动视角，检查字幕、准星、菜单、人物边缘、透明效果是否异常。发现冻结/重复帧/拖影时，不能只用 FPS 数字宣布成功。

脚本的 `LiveTelemetryConsistent` 只说明本轮诊断相互一致，**不是视觉质量认证**。它不能从 JSON 文件验证签名，也不能证明 DLSS-NR 的运行或最终图像独立性。

游戏退出后，文件可能仍留着成功状态。脚本默认检查 PID、进程起始时间和心跳时间；`-Historical` 只供查看归档，永远不作为“现在生效”的证明。

### 关于红色 `Current DLSSG state: OFF`

实测中 OptiScaler 显示红色 OFF，但同一运行的 NVIDIA 状态和 NGX 请求显示 3X 工作。该标签读取 OptiScaler 的内部 `dlssgDetectedInterpolationCount`，不是直接展示上述状态文件。

**具体不一致原因没有完全定位，不应写成“所有红色 OFF 都可忽略”。** 遇到它应完成上面的多源验证；没有这些证据时按未确认处理，不为了变绿而切成 FSR 或添加欺骗参数。更多情况见[排错文档](docs/TROUBLESHOOTING.md)。

## 9. 回退

### 只关 MFG，保留已验证的 NR

正常退出游戏，重新确认获胜的 INI 文件位置，然后：

```powershell
if (Get-Process -Name SkyrimSE -ErrorAction SilentlyContinue) { throw '先正常退出游戏。' }
$before = Join-Path $W ('OptiScaler-before-rollback-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.ini')
Copy-Item -LiteralPath (Join-Path $P 'OptiScaler.ini') -Destination $before
Copy-Item -LiteralPath (Join-Path $W 'backup\OptiScaler-NR-verified.ini') -Destination (Join-Path $P 'OptiScaler.ini') -Force
```

核对 `FGInput=nofg`、`FGOutput=nofg`、`Enabled=false` 位于 `[FrameGen]`，并且 `[Plugins] LoadAsiPlugins=false`。重新启动后 Core 不再由此加载器加载，NR 仍可工作。如果还有其他 ASI 加载器，必须另外检查其加载路径，不能假设关闭这一个就关闭了所有副本。

### 完全回到安装前

按本次记录的新增文件清单移走新增组件，恢复原来的 `SettingsUser.json` 和被修改的 INI。不要删除整个 `SKSE\Plugins`、Upscaling、MO2 overwrite 或游戏根目录；不碰存档、驱动、注册表，也不删除其他 mod 的文件。

## 10. 维护与贡献

本机和 CI 的辅助脚本测试：

```powershell
pwsh -NoProfile -File .\tests\Smoke.ps1
powershell.exe -NoProfile -File .\tests\Smoke.ps1
```

这只测试配置生成、防覆盖和状态判断，不会启动游戏，也不证明别人的显卡/运行时兼容。

提交不同硬件或版本的复现结果时，请记录实际文件版本、哈希、加载关系、NR Dispatch、MFG 状态和视觉问题。去掉用户名、本机完整路径、存档、账号信息、令牌和截图中的隐私，**不要上传原始游戏目录或 NVIDIA 模型**。

感谢 [OptiScaler](https://github.com/optiscaler/OptiScaler)、[Dagherbou/OptiScaler_DLSSNR](https://github.com/Dagherbou/OptiScaler_DLSSNR)、[dashdogy/RTX40MFG-Unlock](https://github.com/dashdogy/RTX40MFG-Unlock)、[NVIDIA Streamline](https://github.com/NVIDIA-RTX/Streamline)、[Community Shaders](https://github.com/doodlum/skyrim-community-shaders)、ShyVortex 的原始参考项目，以及 NR 上游注明的 RenoDX/hhkbble 等贡献者。

本仓库原创教程和脚本使用 [MIT](LICENSE)；引用项目和外部组件各自的许可证不因此改变。
