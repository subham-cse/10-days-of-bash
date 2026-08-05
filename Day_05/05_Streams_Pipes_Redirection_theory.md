# Day 05: POSIX Streams, File Descriptors, Pipes & Redirection Mechanics

## 1. POSIX File Descriptor Architecture & The Kernel Process Table

In Unix-like operating systems, everything is exposed as a file stream. When a process launches, the kernel initializes a File Descriptor (FD) table within the Process Control Block (task_struct in Linux).

```
                      Process Control Block (PCB) / FD Table
                     +--------------------------------------+
                     |  Index  |  Pointer to VFS File Node  |
                     |---------+----------------------------|
                     |  FD 0   |  Standard Input (stdin)    | ──► Keyboard / PTY
                     |  FD 1   |  Standard Output (stdout)  | ──► Terminal Display
                     |  FD 2   |  Standard Error (stderr)   | ──► Terminal Display
                     |  FD 3+  |  Custom Files / Sockets    | ──► Open files / pipes
                     +--------------------------------------+
```

### Standard Stream Properties

| File Descriptor | Name | Constant in C | Default Source / Target | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **0** | `stdin` | `STDIN_FILENO` | Keyboard / PTY stream | Standard input data consumption |
| **1** | `stdout` | `STDOUT_FILENO` | Terminal screen / PTY | Primary program data output |
| **2** | `stderr` | `STDERR_FILENO` | Terminal screen / PTY | Diagnostics, warnings, error reporting |
| **3 - 9** | Custom FDs | User Allocated | Files, FIFOs, Sockets | Custom logging, IPC, non-destructive parsing |

---

## 2. Redirection Syntax & The `dup2()` System Call

Redirection is accomplished in kernel space via the `dup2(oldfd, newfd)` system call before executing the target binary.

```
       Command: cmd > output.log 2>&1

   Step 1: Open 'output.log' with O_WRONLY|O_CREAT|O_TRUNC -> Gets temporary FD X (e.g., 3)
   Step 2: dup2(3, 1)  ──► FD 1 now points to 'output.log'
   Step 3: dup2(1, 2)  ──► FD 2 now points to WHERE FD 1 CURRENTLY POINTS ('output.log')
   Step 4: Close FD 3.
   Result: Both stdout (1) and stderr (2) write into 'output.log'.
```

### Critical Ordering Rule: `> file 2>&1` vs. `2>&1 > file`

```
   CORRECT: cmd > file 2>&1
   FD 1 ──► [ file ]
   FD 2 ──► points to current target of FD 1 (which is [ file ])
   Output: BOTH stdout and stderr captured in [ file ].

   WRONG: cmd 2>&1 > file
   FD 2 ──► points to current target of FD 1 (which is Terminal / PTY)
   FD 1 ──► redirected to [ file ]
   Output: stdout goes to [ file ], BUT stderr STILL PRINTS TO TERMINAL!
```

---

## 3. Redirection Operator Reference Matrix

| Syntax | Action Description |
| :--- | :--- |
| `cmd > file` | Overwrite `stdout` (FD 1) to `file` (creates if missing, truncates if exists). |
| `cmd >> file` | Append `stdout` (FD 1) to `file` atomically (`O_APPEND`). |
| `cmd 2> file` | Overwrite `stderr` (FD 2) to `file`. |
| `cmd 2>> file` | Append `stderr` (FD 2) to `file`. |
| `cmd > file 2>&1` | Merge `stderr` into `stdout`, writing both to `file` (Portable POSIX). |
| `cmd &> file` | Short-hand for redirecting both `stdout` and `stderr` to `file` (Bash-specific). |
| `cmd > /dev/null 2>&1` | Discard all output (stdout + stderr) completely into the null sink. |
| `cmd < file` | Redirect contents of `file` into `stdin` (FD 0). |
| `cmd << 'EOF'` | **Here-Document**: Feed multiline block into `stdin` without subshell. |
| `cmd <<< "$VAR"` | **Here-String**: Feed string directly into `stdin`. |

---

## 4. Pipeline Architecture & The Ring Buffer

When commands are chained via the pipe operator `cmd1 | cmd2`, the kernel creates an anonymous in-memory FIFO buffer.

```
+-------------------+                          +-------------------+
| Process: cmd1     |                          | Process: cmd2     |
|                   |                          |                   |
| stdout (FD 1) ────┼──┐                    ┌──┼──► stdin (FD 0)   |
+-------------------+  │                    │  +-------------------+
                       │                    │
                       ▼                    │
            +-------------------------------------------+
            |      Kernel Anonymous Pipe Ring Buffer     |
            |      (Capacity: 64 KB in Linux 2.6.11+)   |
            +-------------------------------------------+
```

### Key Properties of UNIX Pipelines:
1. **Concurrent Execution**: `cmd1` and `cmd2` run in parallel as child processes, not sequentially.
2. **Backpressure**: If `cmd1` writes faster than `cmd2` reads, the kernel blocks `cmd1` when the 64 KB buffer fills.
3. **`SIGPIPE` Signal**: If `cmd2` terminates early (e.g., `head -n 5`), subsequent writes by `cmd1` trigger `SIGPIPE`, killing `cmd1`.
4. **Exit Code Propagation (`pipefail`)**: In standard POSIX shell, `$?` holds only the exit status of the *last* command (`cmd2`). With Bash `set -o pipefail`, the pipeline fails if *any* command in the chain fails.

---

## 5. Dual-Streaming with `tee` & Process Substitution

```
                      ┌────────────────────────────┐
                      │    Command Output Stream   │
                      └─────────────┬──────────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │      tee -a file     │
                         └──────────┬───────────┘
                                    │
                   ┌────────────────┴────────────────┐
                   ▼                                 ▼
         [ Terminal Screen ]                  [ Log File on Disk ]
```

### Process Substitution: `<(...)` and `>(...)`
Process substitution lets you treat command pipelines as temporary file paths (`/dev/fd/N`), enabling multi-stream diffing and asynchronous routing:

```bash
# Compare output of two remote APIs without saving temporary files to disk
diff -u <(curl -s https://api.prod.com/health) <(curl -s https://api.staging.com/health)

# Feed dual logs simultaneously using tee and process substitution
command 2> >(tee -a errors.log >&2) | tee -a stdout.log
```

---

## 6. Common Pitfalls & Edge Cases

1. **Pipeline Subshell Pitfall**:
   * Commands on both sides of a pipe run in child subshells. Variable mutations inside a pipeline cannot be read by the parent script.
2. **Missing `pipefail`**:
   * `curl https://broken-link.com | grep "success"` returns exit code 1 from grep, but if grep matches an empty string, the pipeline returns 0 unless `set -o pipefail` is active.
3. **Clobbering Protection**:
   * Running `set -o noclobber` prevents accidental file overwriting with `>`. You can force overwrite using `>|`.
