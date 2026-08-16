# DeepSeek Harness Fast Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove per-launch `npx` package resolution and run the pinned local DSH entry directly with Node.js.

**Architecture:** The installer ensures `@deepseek-ai/dsh@0.1.0-rc.6` exists under ignored `runtime/dsh`. The launcher validates that entry and starts it directly with the matching Node 22 executable, retaining ownership of the service process for prompt shutdown.

**Tech Stack:** Windows PowerShell 5.1, Node.js 22, npm local prefix install, existing Edge app-mode launcher.

---

### Task 1: Define fast-start contracts

- [ ] Add failing tests requiring the installer to deploy the pinned package and the launcher to use `node.exe` plus the local `lib/bin.js` entry without `npx.cmd`.
- [ ] Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Launcher.Tests.ps1` and confirm the new assertions fail for the old npx architecture.

### Task 2: Implement local deployment and direct start

- [ ] Add `runtime/` to `.gitignore`.
- [ ] Update the installer to run npm only when the pinned DSH entry/version is absent.
- [ ] Update the launcher to validate the local entry, prepend its matching Node directory, and start `node.exe <entry> web` directly.
- [ ] Update Chinese error resources for a missing local installation.
- [ ] Run unit tests until all assertions pass.

### Task 3: Install, benchmark, and verify

- [ ] Run the installer once to deploy the package and refresh the shortcut.
- [ ] Measure time from launcher start to port 3080 and to the acknowledged Edge app window.
- [ ] Run the full lifecycle verifier and confirm closing the window releases port 3080 while unrelated Node/Edge processes survive.
- [ ] Commit, merge to `master`, reinstall from the main directory, and repeat both unit and lifecycle tests.
