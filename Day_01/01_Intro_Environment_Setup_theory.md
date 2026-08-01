# Day 01: Shell Architectures, Execution Contexts & Environment Setup

## 1. System Architecture: Kernel vs. Shell vs. Terminal Emulator

To master Bash scripting, you must first understand the abstraction layers between human input, process orchestration, and hardware execution in Unix-like operating systems.

```
+-----------------------------------------------------------------------+
|                         Human Operator / User                         |
+-----------------------------------------------------------------------+
                                   |  (Keyboard & Mouse Events)
                                   v
+-----------------------------------------------------------------------+
|  Terminal Emulator (e.g., Alacritty, iTerm2, GNOME Terminal, Windows Terminal) |
|  - Renders glyphs, handles fonts, captures keystrokes                 |
|  - Allocates pseudo-terminal master/slave pair (pty/tty)              |
+-----------------------------------------------------------------------+
                                   |  (Byte Stream via Line Discipline)
                                   v
+-----------------------------------------------------------------------+
|  Shell / Command Language Interpreter (e.g., Bash, Zsh, Dash)         |
|  - Reads characters, parses grammar, tokenizes, expands syntax        |
|  - Manages jobs, tracks environment variables, executes built-ins     |
|  - Forks child processes & calls execve() syscall                     |
+-----------------------------------------------------------------------+
                                   |  (System Calls: fork, execve, wait4, dup2)
                                   v
+-----------------------------------------------------------------------+
|  Operating System Kernel (Linux, macOS Darwin, BSD)                   |
|  - Memory management (MMU, page tables, VMA allocation)              |
|  - Process scheduling (CFS / EEVDF), CPU time-slicing                |
|  - Virtual File System (VFS), device drivers, IPC                     |
+-----------------------------------------------------------------------+
                                   |  (Hardware Control)
                                   v
+-----------------------------------------------------------------------+
|                      Physical Hardware (CPU, RAM, Disks, NIC)         |
+-----------------------------------------------------------------------+
```

### Key Differences at a Glance

| Component | Responsibility | Examples |
| :--- | :--- | :--- |
| **Terminal Emulator** | Window presentation, font rendering, character transmission over `/dev/pts/N`. | `xterm`, `kitty`, `alacritty`, `wezterm` |
| **Shell** | Command interpreter, AST parser, parameter expansion, pipeline plumbing, job control. | `bash`, `sh` (POSIX), `zsh`, `dash` |
| **Kernel** | Privileged supervisor mode, memory mapping, interrupt handling, scheduling processes. | `vmlinuz` (Linux), `xnu` (macOS) |

---

## 2. Under the Hood: Shebang Parsing & The Kernel Loader (`execve`)

When an executable text file is invoked directly via `./script.sh`, the kernel loader interprets the initial magic bytes known as the **Shebang** (`#!`).

```
User enters: ./script.sh
       │
       ▼
sys_execve("./script.sh", argv, envp)  [Kernel Space]
       │
       ├─► Read first 256 bytes from ELF / Script Header
       │
       ├─► Inspect Magic Bytes:
       │     0x7F 'E' 'L' 'F'   ──► Binary ELF Executable -> Direct Load into memory
       │     0x23 0x21 ('#' '!') ──► Shebang Header Detected
       │
       ├─► Parse Interpreter Path:
       │     "#!/usr/bin/env bash"
       │     - Token 1: /usr/bin/env  (The actual executable binary invoked)
       │     - Token 2: bash          (The initial argument passed to env)
       │
       └─► Re-executes kernel loader with:
             execve("/usr/bin/env", ["/usr/bin/env", "bash", "./script.sh"], envp)
                   │
                   ▼
             env searches $PATH, locates /bin/bash, executes:
             execve("/bin/bash", ["bash", "./script.sh"], envp)
```

### Why `#!/usr/bin/env bash` vs `#!/bin/bash`?

* **`#!/bin/bash` (Hardcoded path)**: Fails on systems where Bash resides in `/usr/local/bin/bash` (e.g., FreeBSD, OpenBSD, macOS Homebrew, NixOS).
* **`#!/usr/bin/env bash` (Dynamic PATH lookup)**: Searches the active `PATH` variable to find the user's preferred Bash version. This is the industry standard for portable, cross-platform scripting.

---

## 3. Login vs. Non-Login & Interactive vs. Non-Interactive Shells

A Bash shell process operates under one of four distinct runtime profiles:

```
                          ┌──────────────────────────┐
                          │   Is Standard Input      │
                          │   attached to a tty?     │
                          └─────────────┬────────────┘
                                        │
                       Yes              │             No
            ┌───────────────────────────┴───────────────────────────┐
            ▼                                                       ▼
  [Interactive Shell]                                    [Non-Interactive Shell]
  - Displays prompt ($PS1)                               - Runs scripts (e.g. ./job.sh)
  - Enables history, alias expansion                     - Disables prompt and history
  - Job control active                                   - Strict error exiting
            │                                                       │
    ┌───────┴───────┐                                       ┌───────┴───────┐
    ▼               ▼                                       ▼               ▼
[Login]       [Non-Login]                               [Login]       [Non-Login]
(SSH session, (Subshell, tmux,                          (Automated    (Standard cron job,
 console tty)  new terminal tab)                         batch login)  CI/CD pipeline script)
```

### Configuration File Loading Matrix

| Invocation Mode | Files Loaded (in sequential order) | Common Purpose |
| :--- | :--- | :--- |
| **Interactive Login** | `/etc/profile` &rarr; `~/.bash_profile` (or `~/.bash_login`, `~/.profile`) | Global environment variables, umask, locale |
| **Interactive Non-Login** | `/etc/bash.bashrc` &rarr; `~/.bashrc` | Aliases, shell functions, prompts (`PS1`), keybindings |
| **Non-Interactive Script** | Referenced by `$BASH_ENV` (if set) | Headless background execution, CI/CD runners |

---

## 4. Unix Permissions: Octal Masks, Bits & File Execution

In Unix, file execution is protected at the kernel VFS layer via Permission Bitmasks.

```
       File Mode Representation: -rwxr-xr-x (Octal: 0755)

   Position:  [File Type]   [ Owner / User ]   [ Group ]   [ Others / World ]
   Notation:      -               r w x          r - x           r - x
   Binary:        -               1 1 1          1 0 1           1 0 1
   Octal Sum:     -            (4 + 2 + 1)      (4 + 0 + 1)     (4 + 0 + 1)
   Value:                         = 7             = 5             = 5
```

### Permission Bit Values
* **Read (`r`) = 4** (`0b100`): Permission to open and read file contents or list directory entries.
* **Write (`w`) = 2** (`0b010`): Permission to modify/truncate file or create/delete files inside directory.
* **Execute (`x`) = 1** (`0b001`): Permission to pass file descriptor to `execve()` or traverse (`cd`) directory.

### Executability Requirement
A script requires **both Read and Execute** permissions (`chmod +rx` or `chmod 755`) for the invoking user when executed as `./script.sh`. If only Read permission is set, execution via `./script.sh` yields `Permission denied`, though it can still be parsed as an argument to an explicit shell interpreter (`bash script.sh`).

---

## 5. Common Pitfalls & Defensive Rules

1. **Forgetting `set -euo pipefail`**:
   * Without `set -e`, a failed command allows the script to continue blindly, potentially causing disastrous cascading failures (e.g., `cd /var/temp_app && rm -rf *` wiping `/` if `cd` fails).
2. **Missing Execute Bit (`chmod +x`)**:
   * Attempting to run direct invocations without `chmod 755 script.sh` fails with `EACCES` (Permission Denied).
3. **CRLF Line Endings on Windows Subsystems**:
   * Saving scripts with Windows `\r\n` line endings causes the kernel loader to seek `/usr/bin/env bash\r`, resulting in `No such file or directory`. Always enforce Unix `\n` LF.
