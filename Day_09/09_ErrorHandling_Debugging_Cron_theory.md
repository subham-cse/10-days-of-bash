# Day 09: Defensive Bash, Error Trapping, Debugging, and Cron Automation

## Overview & The Unofficial Strict Mode

By default, Bash scripts execute permissively: undefined variables evaluate to empty strings, failed pipeline commands are silently ignored if the final command succeeds, and script execution continues after non-zero exit codes. In mission-critical automation, this default behavior leads to silent data corruption. 

Adopting **Unofficial Bash Strict Mode** transforms the runtime into a fail-fast, deterministic environment.

```
                    +----------------------------------------------------+
                    |             set -euo pipefail                      |
                    +----------------------------------------------------+
                               |                |                |
             +-----------------+                |                +-----------------+
             v                                  v                                  v
   [ -e : errexit ]                   [ -u : nounset ]                  [ -o pipefail ]
Abort immediately if any           Abort if uninitialized             Pipeline fails if ANY
command returns non-zero           variable is referenced             subcommand returns non-zero
```

---

## 1. Strict Mode Flags Reference Table

| Flag / Option | Full Semantic Name | Behavioral Mechanism | Dangerous Default Behavior Without Flag |
| :--- | :--- | :--- | :--- |
| `set -e` | `errexit` | Immediately exits script if any pipeline or command returns exit code $\ne 0$. | Script plows through errors, potentially deleting wrong paths (e.g. `cd /wrong && rm -rf *`). |
| `set -u` | `nounset` | Treats unset variables as an immediate fatal error during expansion. | Typo `$DEL_DIR` evaluates to empty string `""`, turning `rm -rf "$DEL_DIR/*"` into `rm -rf /*`. |
| `set -o pipefail` | `pipefail` | Pipeline status is the exit code of the *last failing command*, not just the rightmost. | `failing_cmd \| cat` returns exit status `0`, silently concealing crashes. |
| `set -x` | `xtrace` | Prints each command to `stderr` preceded by expanded `PS4` prompt before execution. | Blind execution with no tracing of runtime parameter values. |

---

## 2. Signal Handling Architecture & `trap`

Signals are asynchronous notifications sent by the Linux kernel to a process to inform it of an event or interrupt.

```
  Kernel / User Interrupt (Ctrl+C, SIGTERM, script exit)
                           |
                           v
          +----------------------------------+
          |   Shell Signal Interception      |
          +----------------------------------+
                           |
            [ Match Active Trap Table? ]
                    /              \
                  (Yes)           (No)
                  /                  \
    +---------------------------+   +---------------------------+
    | Execute User Trap Handler |   | Execute Default OS Action |
    | (e.g., cleanup temp files)|   | (Immediate termination)   |
    +---------------------------+   +---------------------------+
```

### Signal Matrix
| Signal Name | Number | Trigger Source | Trappable? | Script Cleanup Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `EXIT` (Pseudo) | 0 | Normal script termination or `exit` | Yes | Universal cleanup (temporary files, locks) |
| `SIGHUP` | 1 | Controlling terminal closed | Yes | Reload config or safely flush state |
| `SIGINT` | 2 | Interactive keyboard interrupt (`Ctrl+C`) | Yes | Abort running tasks & clean partial work |
| `SIGTERM` | 15 | Standard termination request (`kill PID`) | Yes | Graceful container / service shutdown |
| `SIGKILL` | 9 | Force kill (`kill -9 PID`) | **No (Kernel Enforced)** | Cannot be caught or trapped |
| `ERR` (Pseudo) | N/A | Triggered on command failure | Yes | Automated stack tracing and debug dumps |

```bash
# Registering robust cleanup traps
temp_dir=$(mktemp -d)
cleanup() {
    local exit_code=$?
    rm -rf "${temp_dir}"
    printf "Cleanup completed. Exit code: %d\n" "${exit_code}"
}
trap cleanup EXIT
trap 'printf "Interrupted by user.\n" >&2; exit 130' INT TERM
```

---

## 3. Automated Call Stack Tracing with `ERR` Trap

Bash maintains internal introspection arrays:
* `${BASH_SOURCE[@]}`: File paths of current call stack.
* `${FUNCNAME[@]}`: Function names in call stack.
* `${BASH_LINENO[@]}`: Line numbers corresponding to function invocations.

```bash
trace_error() {
    local line_no="$1"
    local bash_cmd="$2"
    local err_code="$3"
    printf "[-] Error on line %s: command '%s' exited with code %s\n" \
        "${line_no}" "${bash_cmd}" "${err_code}" >&2
    
    local i
    for (( i = 1; i < ${#FUNCNAME[@]}; i++ )); do
        printf "    at %s (%s:%s)\n" \
            "${FUNCNAME[$i]}" "${BASH_SOURCE[$i]}" "${BASH_LINENO[$((i-1))]}" >&2
    done
}
trap 'trace_error "${LINENO}" "${BASH_COMMAND}" "$?"' ERR
```

---

## 4. Cron Scheduling & Execution Context

Cron runs automated jobs through `crond` daemon.

```
 * * * * *  /path/to/command arg1 arg2
 | | | | |
 | | | | +----- Day of Week (0 - 7) (Sunday = 0 or 7)
 | | | +------- Month (1 - 12)
 | | +--------- Day of Month (1 - 31)
 | +----------- Hour (0 - 23)
 +------------- Minute (0 - 59)
```

### Interactive Login Shell vs Cron Environment
| Environmental Factor | Interactive Login Shell | Cron Daemon Subshell |
| :--- | :--- | :--- |
| **`$PATH`** | Full user paths (`/usr/local/bin`, `/home/user/.nvm/...`) | Stripped default (`/usr/bin:/bin`) |
| **Environment Config** | Loads `~/.bashrc`, `~/.bash_profile` | Does **not** load shell profiles |
| **Standard Streams** | Interactive TTY terminal | `stdin` closed, `stdout`/`stderr` emailed unless redirected |
| **Working Directory** | Current terminal location | User's `$HOME` directory |

---

## 5. Under the Hood: Signal Interception in the Kernel

When a signal arrives:
1. The Linux kernel pauses the process and checks the process descriptor's `signal_struct`.
2. If Bash registered a handler via the `sigaction` syscall, control jumps to Bash's signal dispatcher.
3. Bash marks the signal as pending until the currently executing command completes (or interrupts long sleep builtins), then evaluates the trapped string within the interpreter context.

---

## 6. Common Pitfalls & Edge Cases

1. **`set -e` in Conditionals**: `set -e` is temporarily ignored inside `if condition`, `while`, or `until` statements. `if failing_cmd; then` will not terminate the script.
2. **Subshell Trap Erasure**: Traps set in the parent shell do not automatically run inside child subshells `(...)` unless explicitly configured or re-declared.
3. **Cron Missing Full Binary Paths**: Running `node script.js` in crontab often fails with `node: command not found`. Always specify `/usr/bin/node` or source environment explicitly.
4. **Capturing Both Stdout and Stderr in Cron**: Always redirect output cleanly in crontab: `* * * * * /path/job.sh >> /var/log/job.log 2>&1`.
