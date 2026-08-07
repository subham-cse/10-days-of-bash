# Day 07: Functions, Positional Arguments, Scoping, and Exit Codes

## Overview & The Shell Execution Context

In Bash, modularity is achieved through functions and parameter manipulation. Unlike compiled languages with rigid stack frames, Bash functions execute within the current shell's process context by default, sharing global variable space unless explicitly declared with `local`. Understanding argument passing, dynamic parameter shifting, scope containment, and exit code propagation is mandatory for writing production-grade CLI tools.

```
+-------------------------------------------------------------------------+
|                              Bash Process                               |
|                                                                         |
|  Global Scope: APP_ENV="production", PID=$$                             |
|                                                                         |
|  +-------------------------------------------------------------------+  |
|  | Function Scope: my_func()                                         |  |
|  |   Positional Parameters: $1, $2, $3 ... (${10})                   |  |
|  |   Local Variables: local my_var="scoped"                          |  |
|  |   Shift pointer: shift 2 ===> ($3 becomes new $1)                |  |
|  |   Exit Contract: return 0..255 (does NOT kill parent shell)       |  |
|  +-------------------------------------------------------------------+  |
|                                                                         |
|  Command Exit / Subshell Contract: exit 0..255 (terminates process)      |
+-------------------------------------------------------------------------+
```

---

## 1. Special Variable Reference & Comparison

| Variable | Semantic Meaning | Usage Context & Behavior |
| :--- | :--- | :--- |
| `$0` | Script invocation name | Name of script or bash shell if interactive |
| `$1` .. `$9` | Positional parameters 1 through 9 | First nine arguments passed to script or function |
| `${10}` .. `${N}` | Positional parameters $\ge 10$ | **Must** use curly braces; `$10` evaluates to `$1` followed by literal `0` |
| `$#` | Argument count | Decimal integer count of passed parameters |
| `$@` | Positional parameter list | Word-splits individually when unquoted; preserves words when quoted `"$@"` |
| `$*` | Positional parameter string | Joins all arguments into a single string separated by first char of `IFS` (`"$*"`) |
| `$?` | Exit status of last command | 8-bit unsigned integer (`0` = success, `1..255` = error) |
| `$$` | Current shell Process ID (PID) | Immutable PID of the running interpreter |
| `$!` | PID of last background process | Useful for job control and process synchronization |

---

## 2. In-Depth Comparison: `"$@"` vs `"$*"` vs `$@`

The handling of whitespace and arrays in parameter expansions is one of the most frequent sources of security vulnerabilities (word splitting / glob injection).

```
Arguments Passed:  "alpha beta"  "gamma delta"  "omega"

1. "$@" (Quoted Array - ALWAYS PREFERRED):
   Element 1: [alpha beta]
   Element 2: [gamma delta]
   Element 3: [omega]

2. "$*" (Quoted Concatenation with IFS=' '):
   Element 1: [alpha beta gamma delta omega]

3. $@ or $* (Unquoted - VULNERABLE):
   Element 1: [alpha]
   Element 2: [beta]
   Element 3: [gamma]
   Element 4: [delta]
   Element 5: [omega]
```

### Demonstration Table
| Syntax | Preserves Internal Spaces? | Produces Single Token or Array? | Safe for File Paths with Spaces? |
| :--- | :--- | :--- | :--- |
| `"$@"` | **Yes** (Strictly Preserved) | Multiple tokens (1:1 array mapping) | **Yes (Best Practice)** |
| `"$*"` | **No** (Merged by IFS) | Single concatenated string | No (flattens arguments) |
| `$@` / `$*` | **No** (Split on IFS) | Arbitrary tokens via field splitting | **Dangerous** (breaks on spaces) |

---

## 3. Dynamic Parameter Shifting: `shift`

The `shift [N]` builtin decreases positional parameter indices by `N` (default `1`). `$2` becomes `$1`, `$3` becomes `$2`, and `$#` decreases by `N`.

```
Initial:   $1="deploy"   $2="--force"   $3="production"   ($# = 3)
           ------------------------------------------------------
shift 1:   $1="--force"  $2="production"                  ($# = 2)
shift 1:   $1="production"                                ($# = 1)
```

### CLI Flag Parsing with `getopts`
The POSIX builtin `getopts optstring varname` parses single-character options:
* If a letter is followed by a colon (`f:`), it requires an argument stored in `$OPTARG`.
* `$OPTIND` holds the index of the next argument to be processed.
* After `getopts` loop, execute `shift $((OPTIND - 1))` to expose remaining non-flag positional arguments.

---

## 4. Function Scoping: `local` vs Global Variables

By default, all Bash variables have global scope across the entire process lifetime. If a function modifies `temp_var`, it mutates any existing `temp_var` outside the function.

```bash
global_var="initial"

bad_function() {
    global_var="mutated"  # Corrupts external environment
    leaked_var="leak"     # Created in global namespace!
}

safe_function() {
    local global_var="isolated" # Shadows outer variable safely
    local inner_calc=42         # Garbage collected on function return
    printf "Inside safe: %s\n" "${global_var}"
}
```

### `return` vs `exit` Architectural Comparison

| Dimension | `return [N]` | `exit [N]` |
| :--- | :--- | :--- |
| **Scope of Impact** | Exits the current function / sourced script | Exits the entire Bash interpreter process |
| **Exit Code Range** | 0 to 255 | 0 to 255 |
| **Subshell Behavior** | Exits subshell if invoked inside `(...)` | Exits subshell or parent process |
| **Use Case** | Propagate status back to caller inside script | Abort execution due to fatal error |

---

## 5. Under the Hood: Exit Status Codes & Bitmasks

The Linux kernel reserves exit statuses as 8-bit unsigned integers ($0 \dots 255$). Any value $> 255$ undergoes modulo arithmetic (`code % 256`).

```
Exit Code Matrix:
  0       : Success (EX_OK)
  1       : General catchall error
  2       : Misuse of shell builtins (syntax error)
  126     : Command invoked cannot execute (permission problem or not executable)
  127     : "Command not found" (binary missing from PATH)
  128     : Invalid argument to exit
  128 + N : Fatal error signal "N" (e.g. 130 = 128 + SIGINT(2); 137 = 128 + SIGKILL(9); 143 = 128 + SIGTERM(15))
```

---

## 6. Common Pitfalls & Edge Cases

1. **Missing Braces for Arguments $\ge 10$**: Writing `$10` evaluates `$1` followed by literal string `"0"`. Always use `${10}`.
2. **Missing `local` Declaration in Recursive Functions**: Variables in recursive functions without `local` will overwrite each other across call depths.
3. **`local` Masking Command Return Codes**:
   ```bash
   # WRONG: local always returns 0, masking failure of command substitution!
   local data=$(failing_command)  # $? is 0!

   # CORRECT: Separate declaration and assignment
   local data
   data=$(failing_command)         # $? captures failing_command status
   ```
4. **Passing Arrays to Functions**: Bash does not pass arrays by value directly through positional parameters. Use namerefs (`declare -n ref=$1`) in Bash 4.3+ or serialize them.
