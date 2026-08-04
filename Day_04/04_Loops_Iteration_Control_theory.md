# Day 04: Loops, Iteration Mechanics & Execution Control Flow

## 1. Loop Architectures in Bash

Bash provides three primary looping constructs, each optimized for specific data structures and operational paradigms.

```
       1. Standard 'for-in' Loop                 2. C-Style Arithmetic Loop
     ┌─────────────────────────────┐           ┌─────────────────────────────┐
     │ for item in "${ARRAY[@]}"   │           │ for (( i=0; i<LIMIT; i++ )) │
     └──────────────┬──────────────┘           └──────────────┬──────────────┘
                    │                                         │
                    ▼ (Iterates over words/tokens)            ▼ (Evaluates arithmetic expressions)
     ┌─────────────────────────────┐           ┌─────────────────────────────┐
     │ Loop Body (Executes per el) │           │ Loop Body (Counter mutated) │
     └─────────────────────────────┘           └─────────────────────────────┘

       3. 'while' Loop (True Gate)               4. 'until' Loop (False Gate)
     ┌─────────────────────────────┐           ┌─────────────────────────────┐
     │  Execute Test / Exit Code   │           │  Execute Test / Exit Code   │
     └──────────────┬──────────────┘           └──────────────┬──────────────┘
                    │                                         │
            Exit 0? │ (Success)                       Exit != 0? │ (Failure)
            ┌───────┴───────┐                         ┌───────┴───────┐
      Yes   ▼         No    ▼                   Yes   ▼         No    ▼
     [Run Body]    [Terminate]                 [Run Body]    [Terminate]
```

---

## 2. Comparison Matrix: Loop Variants

| Construct | Execution Condition | Typical Use Case | Syntax Example |
| :--- | :--- | :--- | :--- |
| **`for ... in`** | Iterates through a finite list of words, glob expansions, or array elements. | Iterating over files, arrays, or predefined service lists. | `for item in "${list[@]}"; do ... done` |
| **`for ((;;))`** | Iterates while arithmetic expression is non-zero. | Numeric indexing, sliding windows, buffer offsets. | `for (( i=0; i<10; i++ )); do ... done` |
| **`while`** | Continues looping as long as test command returns **exit status 0**. | Polling health checks, streaming line-by-line file I/O. | `while read -r line; do ... done < file` |
| **`until`** | Continues looping as long as test command returns **non-zero exit status**. | Waiting for external port availability, lock file release. | `until curl -s "$URL"; do sleep 1; done` |

---

## 3. Under the Hood: The Peril of `for f in $(ls)`

A pervasive anti-pattern in shell scripting is iterating over the output of `ls`:

```
               [ Anti-Pattern: for file in $(ls) ]
                                 │
                                 ▼
                   Command Substitution $(ls)
                                 │
                   Executes ls binary -> Outputs text:
                   "backup 2026.tar.gz"  "report.csv"
                                 │
                                 ▼
                     Word Splitting Phase (IFS)
              Splits on spaces, tabs, and newlines!
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    ▼                            ▼                            ▼
 "backup"                    "2026.tar.gz"               "report.csv"
(CORRUPTED TOKEN 1)         (CORRUPTED TOKEN 2)         (VALID TOKEN)
```

### The Correct Approach: Native Pathname Expansion (Globbing)
```bash
# CORRECT & SECURE: Globbing never word-splits filenames with spaces
shopt -s nullglob # Prevents literal '*.log' if no files match
for file in /var/log/*.log; do
    [[ -f "$file" ]] || continue
    process_log "$file"
done
```

---

## 4. Flow Control: `break` and `continue` with Nesting Levels

Bash supports multi-level loop termination and cycle skipping via an optional integer argument:

```
 Outer Loop (Level 2) : for host in web-01 web-02 web-03
 │
 ├── Inner Loop (Level 1) : for service in nginx redis postgres
 │   │
 │   ├── Case A: continue 1  ──► Skips remaining inner statements, goes to next service
 │   ├── Case B: continue 2  ──► Skips remaining inner & outer, goes to next host
 │   ├── Case C: break 1     ──► Terminates inner service loop, continues outer loop
 │   └── Case D: break 2     ──► Terminates BOTH inner and outer loops immediately
```

### Demonstration Code:
```bash
for outer in 1 2 3; do
    for inner in A B C; do
        if [[ "$outer" -eq 2 && "$inner" == "B" ]]; then
            echo "Breaking out of both loops at outer=$outer, inner=$inner"
            break 2
        fi
        echo "Processing: $outer - $inner"
    done
done
```

---

## 5. Streaming File Processing with File Descriptors

Processing large datasets without buffering the entire file into memory requires stream-based `while` loops:

```
                            Data Stream (e.g. data.csv)
                                         │
                                         ▼
            ┌────────────────────────────────────────────────────────┐
            │   while IFS=',' read -r col1 col2 col3 || [ -n "$col1" ];│
            │   do                                                   │
            │       process_record "$col1" "$col2" "$col3"           │
            │   done < data.csv                                      │
            └────────────────────────────────────────────────────────┘
```
* Note the trailing `|| [ -n "$col1" ]`: Prevents losing the last line of a file if it lacks a terminating newline character.

---

## 6. Common Pitfalls & Edge Cases

1. **Unbounded Infinite Polling**:
   * Running `while true; do check_status; done` without a `sleep` or backoff timer saturates 100% of a CPU core. Always integrate deliberate throttling (`sleep 1`).
2. **Subshell Pipelining in Loops**:
   * As demonstrated in Day 02, feeding a loop via `cat file | while ...` executes the loop inside a subshell. State mutations do not persist. Always redirect via `< file` or process substitution `< <(cmd)`.
3. **Empty Glob Behavior**:
   * Without `shopt -s nullglob`, if `*.txt` matches zero files, the loop executes once with the literal string `"*.txt"`.
