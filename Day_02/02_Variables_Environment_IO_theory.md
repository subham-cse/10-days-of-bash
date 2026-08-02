# Day 02: Variables, Memory Scoping, Environment Inheritance & Safe I/O

## 1. Variable Architecture & Memory Model in Bash

Unlike compiled languages with strict static type systems, Bash is an untyped, string-oriented command interpreter. All variables are internally represented as null-terminated C-strings (`char*`) within the shell's internal symbol table.

```
                  +----------------------------------------------+
                  |         Bash Process Memory Space            |
                  |                                              |
                  |  +----------------------------------------+  |
                  |  |         Internal Symbol Table          |  |
                  |  |  [Name]       [Attributes]   [Value]   |  |
                  |  |  ------------------------------------  |  |
                  |  |  "USER"       att_exported   "alice"   |  |
                  |  |  "COUNT"      att_integer    "42"      |  |
                  |  |  "CONFIG_ARR" att_array      [...]     |  |
                  |  |  "SECRET"     att_readonly   "k8s_91"  |  |
                  |  +----------------------------------------+  |
                  |                       │                      |
                  |                       ▼ (export command)     |
                  |  +----------------------------------------+  |
                  |  |         Environment Vector (envp)      |  |
                  |  |  Array of "KEY=VALUE\0" pointers       |  |
                  |  |  passed to sys_execve() for children   |  |
                  |  +----------------------------------------+  |
                  +----------------------------------------------+
```

### The Whitespace Assignment Rule
In Bash grammar, whitespace is an operator token that delimits words (commands vs. arguments).
* `KEY=value` : Parsed as variable assignment syntax.
* `KEY = value` : Parsed as command `KEY` with argument 1 `=` and argument 2 `value`, triggering `command not found`.
* `KEY= value` : Assigns empty string to `KEY` for the duration of executing command `value`.

---

## 2. Process Inheritance & Environment Propagation

When a process launches another process via the `fork()` and `execve()` system calls, environment variables are copied down the process tree, but modifications in child processes **never** propagate back upward to the parent.

```
+-------------------------------------------------------------+
|  Parent Process (PID 1001: bash)                            |
|  VAR_GLOBAL="Alpha"        (Not exported -> Local to 1001)  |
|  export VAR_ENV="Beta"     (Exported -> Placed in envp)     |
+-------------------------------------------------------------+
                                │
                                ▼  sys_fork() + sys_execve()
+-------------------------------------------------------------+
|  Child Process (PID 1002: child_script.sh)                  |
|  - VAR_GLOBAL is UNDEFINED (Did not cross process boundary)  |
|  - VAR_ENV is "Beta"       (Inherited via envp pointer)     |
|                                                             |
|  Child executes: export VAR_ENV="Modified_Inside_Child"     |
+-------------------------------------------------------------+
                                │
                                ▼ Child exits (exit status 0)
+-------------------------------------------------------------+
|  Parent Process (PID 1001: bash)                            |
|  - VAR_ENV remains "Beta"  (Parent memory remains unmutated)|
+-------------------------------------------------------------+
```

---

## 3. Scoping Matrix: Local vs Global vs Environment vs Subshell

| Scope Level | Declaration Syntax | Visibility in Current Shell | Visibility in Subshell `(...)` | Visibility in Forked Children |
| :--- | :--- | :--- | :--- | :--- |
| **Local** | `local var="val"` (inside func) | Enclosing function only | Inherited if inside subshell | No |
| **Global / Shell** | `var="val"` | Entire current shell | Read-only copy | No |
| **Environment** | `export var="val"` | Entire current shell | Read-only copy | Yes (via `envp`) |
| **Read-only** | `readonly var="val"` | Immutable across shell | Read-only copy | No (unless exported) |

### Parameter Expansion Comparison: `$@` vs `$*`

When handling script arguments (`$1`, `$2`, ...), the distinction between `$@` and `$*` becomes paramount:

| Syntax | Description | Example: `set -- "a b" "c"` |
| :--- | :--- | :--- |
| `"$@"` | Preserves exact word boundaries as individual elements (Standard/Recommended). | Two elements: `"a b"`, `"c"` |
| `"$*"` | Concatenates all positional parameters into a single string using first char of `$IFS`. | Single element: `"a b c"` |
| `$@` or `$*` (unquoted) | Performs unwanted word splitting on space characters. | Three elements: `"a"`, `"b"`, `"c"` |

---

## 4. Quoting Mechanics: Strong vs Weak Quoting

```
Expression           Expansion of $VAR   Escape Sequence Expansion (\n)   Command Substitution $(cmd)
-----------------------------------------------------------------------------------------------------
Single Quotes ('...')     DISABLED (Literal)           DISABLED                        DISABLED
Double Quotes ("...")     ENABLED                      ENABLED                         ENABLED
ANSI-C Quotes ($'...')    DISABLED                     ENABLED (\t, \n, \e)            DISABLED
```

### Demonstration:
```bash
NAME="Ada"
echo '$NAME\n'   # Outputs: $NAME\n
echo "$NAME\n"   # Outputs: Ada\n
echo "$NAME"$'\n'# Outputs: Ada followed by actual newline
```

---

## 5. Safe Input Processing with `read`

Reading interactive user input or structured records requires safe parameterization:

```
                            Standard Input Stream (stdin)
                                         │
                                         ▼
             ┌───────────────────────────────────────────────────────┐
             │       read -r -s -p "Prompt: " -t 10 VAR_NAME         │
             └───────────────────────────────────────────────────────┘
                     │         │         │        │
    Raw Mode (No \) ─┘         │         │        └── Timeout (10 seconds)
                 Silent Mode ──┘         └── Custom Prompt String
                 (Hidden input)
```

### Essential `read` Flags
* **`-r` (Raw Input)**: Disables backslash escape interpretation (Prevents `\n` or `\t` from being stripped). **Mandatory in production scripts.**
* **`-s` (Silent Mode)**: Disables terminal echo (Used for secrets, tokens, and passwords).
* **`-p "Prompt"`**: Displays user prompt string directly to the terminal.
* **`-t <seconds>`**: Sets a strict I/O timeout to prevent hanging in headless automation.
* **`-d <char>`**: Sets custom line delimiter instead of newline.

---

## 6. Common Pitfalls & Anti-Patterns

1. **Subshell Pipeline Variable Loss**:
   ```bash
   # WRONG: The pipeline forks a subshell for the while loop; COUNT is lost upon loop exit!
   COUNT=0
   cat data.txt | while read -r line; do
       ((COUNT++))
   done
   echo "Total: $COUNT" # Outputs 0!

   # CORRECT: Process redirection or file redirection preserves caller shell memory:
   COUNT=0
   while read -r line; do
       ((COUNT++))
   done < data.txt
   echo "Total: $COUNT" # Outputs actual line count
   ```

2. **Unquoted Variable Expansions**:
   ```bash
   FILE="My Project Report.txt"
   rm $FILE    # Expands to: rm "My" "Project" "Report.txt" -> Data loss hazard!
   rm "$FILE"  # Safe: Quoted string preserves space boundaries
   ```
