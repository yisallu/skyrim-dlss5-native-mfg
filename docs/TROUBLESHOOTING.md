# 排错与已知限制

先看本轮的 PID、日志修改时间和 JSON `heartbeat`。游戏退出后留存的成功状态不是当前证据。

## 没有 OptiScaler 菜单

- 确认从正确的 MO2 实例启动 SKSE，而不是 Steam 直接启动游戏。
- MO2 的 Data 视图里应有 `SKSE\Plugins\OptiScaler.dll` 和 `OptiScaler_preload.txt`，文件名拼写和扩展名须正确。
- 已验证的预加载器日志 `d3dx9_42.log` 会记录 `found plugin "OptiScaler" for preloading`，随后加载成功。
- “只有某个 d3dx9_42.dll”不足以证明加载器版本和功能正确。未知文件先核实，不覆盖。
- Insert 是模板中设置的菜单键；出现菜单不等于模型或 FG 已运行。

## Upscaling 已勾选，仍没有 DLSS 输入

检查实际获胜的 `CommunityShaders\SettingsUser.json`：

```json
{ "Disable at Boot": { "Upscaling": false } }
```

这是局部字段，不可覆盖整个配置。再确认 `CommunityShaders.log` 加载了 Upscaling，Upscaling UI 选择 DLSS，且自带帧生成关闭。

本机曾经正是被 `Disable at Boot.Upscaling=true` 阻止。不能把 MO2 的启用勾选当作 CS 内部功能已启用。

## NR 模型找不到/无法初始化

- 0.9.71 把 `nvngx_dlssnr.dll` 放在 `OptiScaler.dll` 旁边。旧的 `nvngx.dll_dlssnr.dll` forwarder 要移走，它不是模型。
- `nvngx_dlss.dll` 也不是 NR 模型。
- 当前固定的是修改版 310.9.16，Authenticode 无效。哈希不符就停，不要关安全软件硬跑。
- 检查 `[Libraries] OptiDllPath` 是否指向实际伴随库目录，而不是游戏根目录或另一个 MO2 实例。
- `[Upscalers] Dx11Upscaler=dlss_12` 是本次 NR/DLSS 桥接路径。
- 有 LoadLibrary 成功记录不等于模型执行。需要本轮 `DlssNr_Dx12::Dispatch`。
- 模型来源不明、哈希不符或安全软件拦截时，停止核实，不关安全软件强行执行。

## 界面上的 DLSS 版本是不是 NR？

这是三个独立文件：

| 文件 | 作用 | 本配方版本 |
| --- | --- | --- |
| `nvngx_dlss.dll` | 超分辨率 SR | 310.9.16，NVIDIA 签名 |
| `nvngx_dlssnr.dll` | Neural Rendering 模型 | 310.9.16 修改版，`Preset=2` |
| `nvngx_dlssg.dll` | NVIDIA 帧生成 | 310.9.16，NVIDIA 签名 |

应分别验证，不能通过更换 SR DLL 代替 NR 集成。

## `Current DLSSG state: OFF` 是红色

分两种情况：

1. 新鲜的底层诊断也未生成：当作未启用排错。
2. 本轮已接受 3X、NVIDIA 提供者正确、Ada 修正就绪、状态正常、时间请求增长：可能是显示/检测不一致；继续检查实际运动输出。

v0.2.0 的 [menu_common.cpp](https://github.com/Dagherbou/OptiScaler_DLSSNR/blob/v0.2.0-dlssnr/OptiScaler/menu/menu_common.cpp) 用 `State::dlssgDetectedInterpolationCount` 决定显示 ON 或 OFF。它不是本教程解锁器状态文件的直接显示。本机记录过红字与底层 3X 不一致。

没有完整定位该计数未更新的原因，**不将其归因于某个确定的单一 bug，也不把它当作普遍可忽略的提示**。不要仅为了文字变绿启用 FSR 替代、全局 GPU 欺骗或叠加加载器。

## Active 已勾选，但实际只有 1 帧

按顺序检查：

1. `FGInput=upscaler`、`FGOutput=dlssg`、`FGNvngxReplacement=None`。
2. 使用的是 `DLSS w/Dx12`，而不是另一个无桥接 backend。
3. FG 的 Streamline 在 `OptiScaler\streamline`，是 SDK 2.14.16 的 `bin\x64` 发布文件，没有覆盖 CS 的 `sl.*.dll`。
4. 只有一个 `MFGUnlocker.asi`，`AdaMfgUnlock=false`，且 `[Plugins] LoadAsiPlugins=true`。
5. 1.6.1 的日志在游戏根目录，文件名类似 `RTXMFG-SkyrimSE-<hash>.log`，不是 v1.2 的 `%TEMP%\MfgUnlock-<PID>.log`。
6. `midpointReadyAtFirstCreate`、`backportReadyAtCreate` 是否为 true；是否提示重启或创建过早。
7. 回到可移动的实际场景，非暂停、加载、切屏状态，重新观察。

解锁器不为游戏提供 FG 输入，本配方的输入由 OptiScaler 桥接提供。不要只安装 Core 就期待 Skyrim 自动具备 MFG。

## JSON 里的 `multiplier=2`，不是设置 3X 吗？

Follow game 模式下，未使用的强制倍率字段可能保留默认 2。关注：

```text
followGame=true
appliedMultiplier=3
gameFrameGenerationOn=true
actualFramesPresented=3
```

不要只因为看到一个默认值就修改解锁器 JSON。检查游戏根目录是否有来自旧安装的强制模式配置；有则先备份和审查。

## 初始化报 Reflex，或切菜单后 FG 暂停

本次日志在初始化和重建阶段出现过 `eDLSSGStatusFailReflexNotDetectedAtRuntime`，之后同一进程采样达到 `dlssgStatus=0`、3 帧呈现。因此：

- 不把一次初始化报错当作后续运行必然失败。
- 也不能忽略持续出现的 Reflex 错误；若状态一直异常，不能宣布成功。
- 模板 `UseGamesReflexMarkers=false` 是测试基线，CS 中未启用额外 Reflex 帧率限制。
- 若正在加载、菜单切换或 Alt-Tab，回实际场景后再看新的状态，必要时按 NR-only 回退。
- 不在两个 Streamline 目录之间来回覆盖 DLL，也不擅自修改驱动全局设置排错。

## 帧率提高，但有拖影、UI 闪烁或手感变差

- 3X 提高输出帧数量，不会让基础 38 FPS 的输入响应变成原生 114 FPS。
- 日志未证明完整 HUD recomposition 输入就绪，字幕、准星和透明 UI 需要实测。
- 独立检查 NR 对人物、光照、细节的改变，再检查 FG 的运动伪影，避免混淆。
- 测试前保留 3X 基线与日志。可以单独做 NR 开/关或 2X 对比，但要标注为新实验，不替换原始复现记录。
- 不把 SDK 报告支持最多 5 张生成帧当作 6X 一定适合 4070 的依据。

## 黑屏、冻结、闪退

先确认是初始化等待，还是持续无响应。不要对用户正在游玩的会话直接强制结束。

可以正常退出时先退出，保留本轮日志和崩溃记录，再恢复经过验证的 NR-only INI。如果 NR-only 也失败，再回退到安装前。不要继续叠加另一套 DLSS Enabler、ASI loader 或 FG 插件。

本次没有完成长时间稳定性验证。双 Streamline 实例、桥接和修改模型都增加兼容性风险；一次短会话成功不等于任意整合包都稳定。

## CSV/FPS 是否能证明每张生成图都不同？

不能。

`MfgUnlock-intervals-<PID>.csv` 记录的是 NGX 时间请求和 CPU 提交间隔。`count=2`、1/3 和 2/3 表明发出了两个不同时间位置的请求，但不独立证明最终显示图像没有重复。

解锁器源码中的 FPS 统计在没有输出呈现回调时可以使用基础帧采样乘以呈现倍率估算。最终帧间隔、独立性和延迟需要另行采集与对比；不能把约 113.4 FPS 写成经过独立工具认证的结果。

## 提交问题前的脱敏清单

- 描述 GPU、驱动、运行时、SKSE、CS/Upscaling 和固定组件版本。
- 摘录必要的配置字段和诊断状态，而非完整原始日志。
- 去掉用户目录、机器名、存档名、账号、令牌、Cookie 和截图中的私人信息。
- 不上传 NVIDIA 模型、第三方 DLL、游戏/存档文件。
- 明确日志是本轮正在运行、已经退出的历史记录，还是人工测试样例。
