# 给其他 AI 的复现协议

把下面的提示词连同本仓库链接交给具有本机文件/终端权限的 AI。纯对话 AI 只能指导，不能声称替用户完成了本机安装。

## 可直接使用的提示词

```text
请按这个仓库的 README、versions.json 和排错文档，为我的 Skyrim SE +
Community Shaders + MO2 配置 DLSS-NR 和 NVIDIA 原生 3X MFG。

先读取本机适用的 AGENTS.md，检查实际游戏运行时、SKSE、CS/Upscaling 版本、
GPU/驱动、MO2 当前实例/profile、文件优先级、overwrite、加载器和已有代理 DLL。
旧文档和文件名不优先于 EXE/DLL 版本及运行日志。

目标是 NVIDIA nvngx_dlssg.dll，FGNvngxReplacement=None。
不接受 FSR/Arturs/Nukem/XeFG 替代，也不要只看到官方 RTX 50 限制就断言
RTX 4070 不可能使用本仓库记录的非官方路线。

先核实 nvngx_dlssnr.dll 是否为 versions.json 里的 310.9.16 指纹。缺少或哈希不符时说明
前提未满足。不要虚构下载来源，不把 SR/RR 文件改名充数，也不要运行 dlss-unlocked 安装器。

严格固定版本和哈希，保留现有 CS Streamline，独立部署 FG Streamline。
只有在游戏正常退出后才能修改 DLL/设置。先备份，先跑通 NR-only，
再加载 MFG Unlocker 1.6.1（只保留 MFGUnlocker.asi）并请求 3X。不要同时设置 AdaMfgUnlock=true。不要操作存档、驱动、注册表或安全设置。

不要整包运行 dlss-unlocked 安装器，不运行 setup_windows.bat 或签名覆盖 reg。
遵循 MO2 布局，优先使用本机已验证兼容的 SKSE preloader。
不要覆盖其他代理 DLL，不叠加两个 ASI Core，不启用 CS 内置 FSR FG。

分别验证 NR Dispatch 与原生 MFG。核对当前 PID/心跳、NVIDIA FG 提供者、
Ada midpoint 修正、appliedMultiplier、actualFramesPresented、dlssgStatus、
持续增长的 NGX 时间请求。FPS 或 Active 勾选不能单独作证。

对红色 OFF 不预设结论：此仓库记录过 UI/底层不一致，但不是所有 OFF 都是误报。
如果无法确认，保留日志并报告未确认；不通过换成 FSR 来伪装完成目标。

最后说明改了哪些文件、实测到了哪一步、尚未验证的风险和回退方法。
不要把历史日志或仓库示例状态当成我的本轮运行结果。
```

## 执行顺序和停止条件

| 阶段 | 必须得到的结果 | 不满足时 |
| --- | --- | --- |
| 只读盘点 | 正确的实例/profile、实际运行时、现有 DLL 和获胜文件 | 继续查证，不猜路径 |
| 前提 | 模型合法来源和兼容性、基础 Upscaling 已可用 | 缺模型时询问用户，不能完成 NR |
| 备份 | 本轮独立备份目录、新增文件清单、回退 INI | 不做修改 |
| 部署 NR | 合适预加载器加载、DLSS w/Dx12、实际 NR Dispatch | 停留本阶段排错 |
| 部署 MFG | FG Streamline 独立、仅一个 Core、请求 3X | 不添加其他替代器 |
| 运行验证 | 新 PID、新日志、多源底层证据一致 | 不宣布已启用 |
| 视觉验证 | 在活动场景观察运动和 HUD，记录异常 | 问题严重时回退 NR-only |
| 交付 | 文件变更、证据、限制、回退说明 | 不把“复制成功”写成“游戏验证成功” |

## 必须保持的边界

- 当前游戏运行时才是事实。实测 1.5.97，不要照旧说明擅自升级为 1.6.1170 或安装另一套 SKSE。
- 对文件和 JSON 使用原生、结构化 API；别用正则替换整个用户设置文件。
- 不能把本仓库的局部 CS JSON 示例当作完整设置文件覆盖用户配置。
- 遇到现有文件先比较和备份，合并用户已有改动。`New-Config.ps1` 默认 NR-only，禁止覆盖输出，故意不承担安装。
- 保存并正常退出游戏才能切换 DLL/INI。卡启动和正在游玩的会话要区分，不杀有未保存进度的游戏。
- 不静默取消安全设置、替换系统 NGX、安装驱动或运行陌生注册表脚本。
- 第三方修改模型与原生 FG 提供者是两回事。模型哈希不是签名；本配方 FG 提供者应为 NVIDIA 签名有效的原文件。
- `MFGUnlocker.dll` 改名为 `MFGUnlocker.asi` 只针对记录的 v1.6.1。不要和 `AdaMfgUnlock=true` 或第二份解锁器一起加载。
- 初始使用固定 3X，不因 `numFramesToGenerateMax=5` 就切到 6X；容量不等于实测质量。
- 保留 NR-only 回退，不以 FSR 的成功替代 NVIDIA 路线的失败。
- 任何上传仅包含脱敏资料；不上传模型、插件二进制、存档、完整用户日志或账号信息。

## 证据标准

分别报告以下四个层次，不要混成一句“全部正常”：

1. **部署完成**：文件、版本、哈希和配置正确。
2. **运行调用成立**：NR 有实际 Dispatch，原生 MFG 的提供者、修正和状态一致且属于当前进程。
3. **输出视觉检查**：实际移动、转视角、菜单/HUD 场景是否出现冻结、重复、拖影。
4. **性能/稳定性实验**：是否测过最终呈现间隔、独立帧、端到端延迟和长时间稳定性。

本仓库有第 1、2 层的实测记录，第 3 层只有有限观察，第 4 层未完成。其他 AI 应如实报告自己达到的层次，不继承本仓库的结果作为自己的实测。

## 完成报告建议

```text
实际环境：
本轮新增/修改文件：
未改动的组件：
NR 验证结果：
原生 MFG 验证结果：
视觉检查与未验证项：
失败/回退情况：
备份和回退方法：
```
