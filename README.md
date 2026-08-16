# DeepSeek Harness Launcher

<p align="center">
  <img src="assets/deepseek-harness.png" width="180" alt="DeepSeek Harness Launcher icon">
</p>

<p align="center">
  Windows 桌面启动器：双击图标，在独立的 Edge 应用窗口中运行 DeepSeek Harness，无需一直保留终端。<br>
  A Windows desktop launcher for running DeepSeek Harness in an isolated Edge app window without keeping a terminal open.
</p>

> [!IMPORTANT]
> 本项目是非官方的本地启动器，不隶属于 DeepSeek，也不修改 DeepSeek Harness 本体。上游项目：[`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness)。

## 中文

### 功能

- 桌面快捷方式名称和图标均为 DeepSeek Harness 风格。
- 启动时不显示 PowerShell 终端窗口。
- 直接运行固定版本 `@deepseek-ai/dsh@0.1.0-rc.6`，减少每次启动时的 `npx` 检查时间。
- 在独立的 Microsoft Edge 应用窗口中打开 `http://127.0.0.1:3080`。
- 关闭应用窗口后，自动停止本次启动的 DSH 进程并清理专用 Edge 进程。
- 使用独立 Edge 用户数据目录，不影响日常浏览器配置。
- 检测端口占用、Node.js、DSH 运行时和 Edge，并以中文提示常见错误。

### 系统要求

- Windows 10 或 Windows 11
- Node.js 22 或更高版本，包含 `npm`
- Microsoft Edge
- 可访问 npm 注册表的网络连接（首次安装或本地缓存不可用时）

### 安装

```powershell
git clone https://github.com/1WenJWen1/deepseek-harness-launcher.git
cd deepseek-harness-launcher
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Install-DeepSeekHarness.ps1
```

安装脚本会把固定版本的 DSH 依赖部署到本项目的 `runtime/dsh` 目录，并在桌面创建 `DeepSeek Harness.lnk`。`runtime/` 只存在于本机，不会提交到 Git。

### 使用

1. 双击桌面的 **DeepSeek Harness** 图标。
2. 等待独立应用窗口出现。首次启动或磁盘较慢时可能需要数秒。
3. 正常点击窗口右上角的 `×` 即可退出；启动器会同时停止后台服务。

如果看到“端口 3080 已被占用”，请先关闭其他 DSH 实例或占用该端口的程序，再重新打开。

### 测试

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Launcher.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Verify-Installation.ps1
```

第二项是完整生命周期测试：它会实际启动应用、关闭窗口，并确认端口和专用 Edge 进程已清理。

### 项目结构

```text
assets/                         图标源文件和 Windows 图标
resources/messages.zh-CN.json  中文错误信息
src/Install-DeepSeekHarness.ps1 安装固定版本运行时并创建桌面快捷方式
src/Launcher.Core.ps1          Node、端口和进程管理工具
src/Start-DeepSeekHarness.ps1  隐藏启动、等待就绪、打开窗口和退出清理
tests/Launcher.Tests.ps1        静态与单元检查
tests/Verify-Installation.ps1  Windows 端到端生命周期验证
```

### 安全边界

- Web 服务使用上游默认配置，仅监听 `127.0.0.1:3080`，不是面向公网的服务。
- 安装器固定 DSH 版本，但首次联网安装仍依赖 npm 注册表和上游依赖链。
- 启动器、项目目录和 Node.js 运行时均位于当前 Windows 用户可写目录；不要在不受信任的共享账户中使用。
- DSH 是可以调用本地工具的智能体程序。请只授权你理解的操作，并自行保护 API 密钥、源码和本机数据。

## English

### Features

- Branded desktop shortcut and icon.
- Hidden PowerShell host with no terminal window left open.
- Direct launch of pinned `@deepseek-ai/dsh@0.1.0-rc.6` for faster repeated startup.
- Isolated Microsoft Edge app window at `http://127.0.0.1:3080`.
- Automatic cleanup of the owned DSH process tree and isolated Edge processes when the window closes.
- Checks for port conflicts, Node.js, the local DSH runtime, and Microsoft Edge.

### Requirements and installation

Windows 10/11, Node.js 22+, npm, and Microsoft Edge are required.

```powershell
git clone https://github.com/1WenJWen1/deepseek-harness-launcher.git
cd deepseek-harness-launcher
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Install-DeepSeekHarness.ps1
```

Double-click **DeepSeek Harness** on the desktop. Close the app with the normal `×` button; the launcher then shuts down the local service and its isolated Edge processes.

### Security and disclaimer

This repository is an unofficial convenience launcher. It is not affiliated with or endorsed by DeepSeek. DeepSeek Harness itself is provided by the upstream [`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness) project and remains subject to its own license, behavior, and security model.

The local web service is expected to bind to loopback only. The installer pins the top-level DSH version, but npm and transitive dependencies remain part of the software supply chain. Review permissions carefully before allowing an AI agent to access local files, shells, credentials, or external services.

## License

No separate license has been granted for this launcher unless a license file is added to the repository. The DeepSeek name, upstream code, and related assets remain the property of their respective owners.
