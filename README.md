# 10 Days of Bash: Enterprise Automation & Shell Scripting Mastery

Welcome to **10 Days of Bash**, an intensive, production-grade curriculum designed for DevOps engineers, Site Reliability Engineers (SREs), and Linux Systems Administrators. This repository provides end-to-end theoretical foundations and fully executable, zero-dependency Bash automation scripts across 10 sequential modules.

---

## 📚 Curriculum Roadmap & Index

| Day | Module & Core Concepts | Architectural Theory Guide | Production Shell Script |
| :---: | :--- | :--- | :--- |
| **Day 01** | **Intro & Environment Setup**<br>• Shell vs Kernel vs Terminal<br>• Login vs Non-login Shells<br>• Shebang (`#!`) Kernel Loader Mechanics<br>• POSIX Permissions & Octal Masks | [Theory Guide](Day_01/01_Intro_Environment_Setup_theory.md) | [System Inspector Script](Day_01/01_Intro_Environment_Setup_script.sh) |
| **Day 02** | **Variables, Environment & I/O**<br>• Variable Memory Allocation<br>• `export` & Environment Inheritance<br>• Subshell Isolation<br>• Safe `read` with Timeouts & Silent Masking | [Theory Guide](Day_02/02_Variables_Environment_IO_theory.md) | [Dynamic Config Generator](Day_02/02_Variables_Environment_IO_script.sh) |
| **Day 03** | **Conditionals & Test Operators**<br>• `test` vs `[` vs `[[ ... ]]`<br>• Integer vs String vs Regex Matching<br>• Unary File Operators (`-f`, `-d`, `-r`, `-w`, `-x`)<br>• Defensive Compound Logic | [Theory Guide](Day_03/03_Conditionals_Test_Operators_theory.md) | [System Diagnostic Utility](Day_03/03_Conditionals_Test_Operators_script.sh) |
| **Day 04** | **Loops, Iteration & Control**<br>• Internal Iterator & C-Style For Loops<br>• `while` vs `until` State Control<br>• Process Iteration & Infinite Loops<br>• Loop Cycle Control (`break` / `continue`) | [Theory Guide](Day_04/04_Loops_Iteration_Control_theory.md) | [Batch Service Monitor](Day_04/04_Loops_Iteration_Control_script.sh) |
| **Day 05** | **Streams, Pipes & Redirection**<br>• POSIX File Descriptors (`0: stdin`, `1: stdout`, `2: stderr`)<br>• `/dev/null` & Stream Merging (`2>&1`)<br>• Atomic Redirection (`>` vs `>>`)<br>• Pipe Buffer Mechanics (`pipe(2)`) | [Theory Guide](Day_05/05_Streams_Pipes_Redirection_theory.md) | [Multi-Stream Logger](Day_05/05_Streams_Pipes_Redirection_script.sh) |
| **Day 06** | **Text Processing (Grep, Sed, Awk)**<br>• POSIX Regex Engines (BRE vs ERE)<br>• `sed` Stream Editing & Pattern Spaces<br>• `awk` Columnar Slicing (`FS`, `NR`, `NF`)<br>• High-Throughput Stream Buffering | [Theory Guide](Day_06/06_Text_Processing_Grep_Sed_Awk_theory.md) | [Access Log Analyzer](Day_06/06_Text_Processing_Grep_Sed_Awk_script.sh) |
| **Day 07** | **Functions, Arguments & Exit Codes**<br>• Positional Parameters (`$1`..`${10}`)<br>• Parameter Shifting (`shift`)<br>• Variable Scoping (`local` vs Global)<br>• 8-Bit Unsigned Exit Codes & Sysexits | [Theory Guide](Day_07/07_Functions_Arguments_ExitCodes_theory.md) | [Modular CLI Engine](Day_07/07_Functions_Arguments_ExitCodes_script.sh) |
| **Day 08** | **Arrays, Arithmetic & String Operations**<br>• Indexed & Associative Arrays<br>• Parameter Expansion & String Manipulation<br>• 64-bit Integer Arithmetic (`$(( ... ))`)<br>• Memory Allocation & Slicing | [Theory Guide](Day_08/08_Arrays_Arithmetic_StringOps_theory.md) | [Resource Telemetry Aggregator](Day_08/08_Arrays_Arithmetic_StringOps_script.sh) |
| **Day 09** | **Error Handling, Debugging & Cron**<br>• Unofficial Strict Mode (`set -euo pipefail`)<br>• Trace Debugging (`set -x`, `PS4` tuning)<br>• Signal Interception & Cleanup via `trap`<br>• Cron Scheduling & Subshell Pitfalls | [Theory Guide](Day_09/09_ErrorHandling_Debugging_Cron_theory.md) | [Resilient Execution Wrapper](Day_09/09_ErrorHandling_Debugging_Cron_script.sh) |
| **Day 10** | **Capstone: Enterprise Backup & Rotation**<br>• Multi-Layer Compression Architectures<br>• POSIX `tar` Blocks & `gzip` Streams<br>• 7-Day Retention Pruning Lifecycle<br>• Integrity Verification (`tar -tzf`) | [Theory Guide](Day_10/10_Capstone_Backup_LogRotation_theory.md) | [Enterprise Backup Utility](Day_10/10_Capstone_Backup_LogRotation_script.sh) |

---

## 🛠️ Repository Architecture & Engineering Standards

Every day's directory is completely self-contained and adheres to strict production engineering guidelines:

1. **Zero Truncation / No Placeholders**: Every script is 100% complete, executable, and contains full business logic without any `# TODO` or stub code.
2. **Defensive Shell Architecture**:
   - Explicit shebang declaration: `#!/usr/bin/env bash`
   - Strict mode enabled: `set -euo pipefail`
   - Scoped function local variables (`local var_name`)
   - Standardized ANSI color-coded logging (`[INFO]`, `[WARN]`, `[ERROR]`, `[SUCCESS]`)
   - Resource cleanup using `trap` handlers on exit and termination signals (`EXIT`, `INT`, `TERM`)
3. **Exhaustive Theory Architecture**:
   - Text/ASCII architecture diagrams illustrating kernel/subshell mechanics
   - Side-by-side comparative feature tables
   - "Under the Hood" OS kernel execution internals (`fork(2)`, `execve(2)`, `dup2(2)`, pipe buffer sizing)
   - Edge cases, common pitfalls, and security considerations

---

## 🚀 Step-by-Step Guide: How to Run the Bash Code

Follow these step-by-step instructions to execute the scripts across Linux, macOS, or Windows.

---

### Step 1: Open Your Terminal Environment

Depending on your operating system, choose one of the following terminal environments:

- **Linux (Ubuntu, Debian, RHEL, Fedora, Arch, etc.)**:
  Open your default system terminal (`Ctrl + Alt + T` or search for "Terminal").
- **macOS**:
  Open **Terminal** (`Cmd + Space` -> type `Terminal`) or **iTerm2**.
  > *Note*: macOS ships with Zsh by default. The scripts will automatically invoke Bash via the `#!/usr/bin/env bash` shebang.
- **Windows**:
  - **Option A (Recommended - WSL2)**: Open Windows Terminal and launch your Ubuntu / Debian WSL distribution:
    ```powershell
    wsl
    ```
  - **Option B (Git Bash)**: Launch **Git Bash** from the Start Menu or context menu.

---

### Step 2: Navigate to the Repository Directory

Navigate into the root of the cloned or generated `10-Days-of-Bash` repository:

```bash
# Example path (adjust to where you have placed the repo)
cd ~/10-Days-of-Bash
```

Verify your present working directory and list the day modules:
```bash
pwd
ls -la
```

---

### Step 3: Grant Executable Permissions

In Unix-like environments, scripts require execute (`x`) permissions before they can be run directly. Run the following command from the repository root to grant execute permissions to all scripts at once:

```bash
chmod +x Day_*/*.sh
```

To verify permissions:
```bash
ls -l Day_01/01_Intro_Environment_Setup_script.sh
# Expected output shows '-rwxr-xr-x' (executable by user, group, others)
```

---

### Step 4: Execute a Script

You can execute any script using either **Direct Execution** (recommended) or **Interpreter Execution**:

#### Method A: Direct Execution (Uses the Shebang `#!/usr/bin/env bash`)
```bash
# Day 01: System Environment Inspector
./Day_01/01_Intro_Environment_Setup_script.sh

# Day 02: Dynamic Variable & Config Generator
./Day_02/02_Variables_Environment_IO_script.sh

# Day 03: Automated System Diagnostic Utility
./Day_03/03_Conditionals_Test_Operators_script.sh
```

#### Method B: Explicit Interpreter Execution
If execute permissions are not set or you want to explicitly invoke a specific bash binary:
```bash
bash Day_01/01_Intro_Environment_Setup_script.sh
```

---

### Step 5: Supplying Arguments & Flags to CLI Scripts

Several scripts (such as Day 07 and Day 10) support command-line flags and parameters:

```bash
# Day 07: Test the modular CLI option parser
./Day_07/07_Functions_Arguments_ExitCodes_script.sh -h              # Display help/usage
./Day_07/07_Functions_Arguments_ExitCodes_script.sh -a -b -f /etc/hosts -v

# Day 06: Analyze access logs (creates sample data if none provided)
./Day_06/06_Text_Processing_Grep_Sed_Awk_script.sh

# Day 08: Run system telemetry aggregation
./Day_08/08_Arrays_Arithmetic_StringOps_script.sh

# Day 09: Run the fault-tolerant execution wrapper with trap stack-traces
./Day_09/09_ErrorHandling_Debugging_Cron_script.sh

# Day 10: Run the enterprise backup and 7-day retention engine
./Day_10/10_Capstone_Backup_LogRotation_script.sh
```

---

### Step 6: How to Run in Debug Mode (Trace Execution)

To inspect step-by-step execution, observe variable expansion, and trace flow line-by-line, pass the `-x` (xtrace) flag:

```bash
# Print each command with expanded variables before executing
bash -x Day_03/03_Conditionals_Test_Operators_script.sh

# Verbose mode (prints raw script lines as they are read)
bash -v Day_01/01_Intro_Environment_Setup_script.sh

# Combined verbose and trace mode
bash -xv Day_07/07_Functions_Arguments_ExitCodes_script.sh -v
```

---

### Step 7: Testing Individual Code Snippets Interactively

To test individual snippets or functions from any day's theory guide without running the entire file:

1. Start an interactive subshell:
   ```bash
   bash
   ```
2. Paste the desired snippet directly into your terminal prompt:
   ```bash
   # Example: Test parameter expansion from Day 08
   filepath="/var/log/nginx/access.log"
   echo "Filename: ${filepath##*/}"       # Output: access.log
   echo "Directory: ${filepath%/*}"        # Output: /var/log/nginx
   echo "Extension: ${filepath##*.}"       # Output: log
   ```
3. Exit the subshell when finished:
   ```bash
   exit
   ```

