# DeepSeek Harness Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and install a single-icon Windows launcher that runs DeepSeek Harness without a visible terminal and stops its DSH process tree when the Edge app window closes.

**Architecture:** A focused PowerShell launcher owns the DSH child process, probes port 3080, opens an isolated Edge app-mode window, monitors that window, and cleans up in `finally`. A separate installer creates a desktop shortcut using a generated local icon; functional helpers are dot-sourced and tested without launching the full application.

**Tech Stack:** Windows PowerShell 5.1-compatible scripts, Microsoft Edge app mode, `npx.cmd`, Windows Script Host shortcuts, native TCP/process commands.

---

## File map

- `src/Launcher.Core.ps1`: pure and testable helpers for executable lookup, port probing, Edge window detection, and owned process-tree cleanup.
- `src/Start-DeepSeekHarness.ps1`: orchestration, error messages, startup timeout, Edge lifetime monitoring, and cleanup.
- `src/Install-DeepSeekHarness.ps1`: desktop shortcut creation and icon assignment.
- `tests/Launcher.Tests.ps1`: dependency-free PowerShell assertions for helper behavior and syntax.
- `assets/deepseek-harness.ico`: blue whale-style launcher icon.

### Task 1: Core helper tests and implementation

**Files:**
- Create: `tests/Launcher.Tests.ps1`
- Create: `src/Launcher.Core.ps1`

- [ ] **Step 1: Write failing tests**

Create tests that dot-source the core file and assert: `Test-LocalPort` returns false for a deliberately unused listener port; `Resolve-CommandPath` returns an existing path for `node.exe`; and `Stop-OwnedProcessTree` ignores PID 0 and the current PowerShell PID. Run with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Launcher.Tests.ps1
```

Expected: failure because `src/Launcher.Core.ps1` does not exist.

- [ ] **Step 2: Implement minimal helpers**

Implement these stable interfaces:

```powershell
function Resolve-CommandPath([string] $Name) { }
function Test-LocalPort([int] $Port, [int] $TimeoutMilliseconds = 250) { }
function Get-EdgeWindowProcesses([string] $ProfilePath) { }
function Stop-OwnedProcessTree([int] $ProcessId) { }
```

`Resolve-CommandPath` uses `Get-Command`; `Test-LocalPort` uses `System.Net.Sockets.TcpClient`; Edge lookup correlates `Win32_Process.CommandLine` with the isolated profile path and returns only processes with a non-zero `MainWindowHandle`; cleanup invokes `taskkill.exe /PID <id> /T /F` only for a positive PID other than `$PID`.

- [ ] **Step 3: Run tests**

Run the same test command. Expected: `PASS` lines for every assertion and exit code 0.

- [ ] **Step 4: Commit**

```powershell
git add src/Launcher.Core.ps1 tests/Launcher.Tests.ps1
git commit -m "feat: add launcher process helpers"
```

### Task 2: Launcher orchestration

**Files:**
- Create: `src/Start-DeepSeekHarness.ps1`
- Modify: `tests/Launcher.Tests.ps1`

- [ ] **Step 1: Add syntax and contract tests**

Parse the launcher with `[System.Management.Automation.Language.Parser]::ParseFile`, assert zero parse errors, and assert the file contains `try`, `finally`, `Start-Process`, `--app=http://127.0.0.1:3080`, and `Stop-OwnedProcessTree`.

- [ ] **Step 2: Run tests and observe failure**

Run the test script. Expected: failure because the launcher is absent.

- [ ] **Step 3: Implement orchestration**

The launcher must:

1. dot-source `Launcher.Core.ps1`;
2. resolve `npx.cmd` and Edge from standard installation paths;
3. refuse startup if port 3080 is already listening;
4. start `npx.cmd --yes @deepseek-ai/dsh web` hidden and retain its wrapper PID;
5. wait up to 90 seconds for the port;
6. start Edge with a dedicated profile, `--app=http://127.0.0.1:3080`, `--disable-background-mode`, and startup-boost disabled;
7. wait for a visible matching window, then detect its closure;
8. show Chinese Windows message boxes for dependency, timeout, port, or Edge failures;
9. call `Stop-OwnedProcessTree` from `finally` for only the stored DSH PID.

- [ ] **Step 4: Run tests**

Expected: all syntax and contract assertions pass.

- [ ] **Step 5: Commit**

```powershell
git add src/Start-DeepSeekHarness.ps1 tests/Launcher.Tests.ps1
git commit -m "feat: orchestrate hidden DSH app window"
```

### Task 3: Icon and desktop installer

**Files:**
- Create: `assets/deepseek-harness.png`
- Create: `assets/deepseek-harness.ico`
- Create: `src/Install-DeepSeekHarness.ps1`
- Modify: `tests/Launcher.Tests.ps1`

- [ ] **Step 1: Generate icon asset**

Create a distinct DeepSeek-inspired blue whale/chat icon on a transparent or deep-blue background, then convert it to a multi-size Windows `.ico` containing at least 256, 48, 32, and 16 pixel representations.

- [ ] **Step 2: Add installer tests**

Parse the installer and assert zero syntax errors. Assert its shortcut target is Windows PowerShell, arguments contain `-WindowStyle Hidden`, `-ExecutionPolicy Bypass`, and the absolute launcher path, and `IconLocation` points to the `.ico` file.

- [ ] **Step 3: Run tests and observe failure**

Expected: failure because the installer is absent.

- [ ] **Step 4: Implement and run installer**

Use `WScript.Shell.CreateShortcut` to create exactly one shortcut named `DeepSeek Harness.lnk` in the current user's Desktop known folder. Set working directory, description, hidden PowerShell arguments, and icon. Do not create a stop shortcut or startup entry.

- [ ] **Step 5: Run tests and commit**

Expected: tests pass and the shortcut exists.

```powershell
git add assets src/Install-DeepSeekHarness.ps1 tests/Launcher.Tests.ps1
git commit -m "feat: install branded desktop launcher"
```

### Task 4: End-to-end verification

**Files:**
- Create: `tests/Verify-Installation.ps1`
- Create: `outputs/README.txt`

- [ ] **Step 1: Write installation verification**

Verify the shortcut target, arguments, icon existence, Node/npx resolution, Edge existence, and initial port state. The script must report each check and exit non-zero on any failure.

- [ ] **Step 2: Verify real startup**

Launch the shortcut, confirm port 3080 listens within 90 seconds, confirm an Edge process using the isolated profile has a visible app window, and confirm no console window is created by the launcher.

- [ ] **Step 3: Verify real shutdown**

Close only the isolated Edge app-window process, wait up to 20 seconds, and assert port 3080 is no longer listening. Confirm unrelated Edge and Node processes remain untouched.

- [ ] **Step 4: Document use and commit**

Write a short Chinese README explaining double-click startup, `×` shutdown, the local URL, and how to rerun the installer. Run all tests and commit.

```powershell
git add tests/Verify-Installation.ps1 outputs/README.txt
git commit -m "test: verify launcher installation lifecycle"
```

## Self-review result

- Spec coverage: single shortcut, branding, hidden startup, Edge app mode, port conflict, dependency errors, owned-process cleanup, and end-to-end verification are all mapped to tasks.
- Placeholder scan: no deferred implementation markers remain.
- Interface consistency: all tasks use the same four core helper names and port 3080.
