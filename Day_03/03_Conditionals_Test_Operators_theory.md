# Day 03: Conditionals, Test Operators & Pattern Matching

## 1. The Mechanics of Truth in Unix: Exit Status Codes

Unlike traditional programming languages where `true = 1` and `false = 0`, Unix and Bash invert this paradigm at the process level:

```
               Command Execution / Expression Evaluation
                                   │
                                   ▼
                         Process Exit Status ($?)
                                   │
                 ┌─────────────────┴─────────────────┐
                 ▼                                   ▼
          Exit Status: 0                     Exit Status: 1 - 255
     =============================       =============================
      SUCCESS / TRUTH / VALID             FAILURE / ERROR / INVALID
     - Triggers 'if' then branch         - Triggers 'else' branch
     - Continues 'cmd1 && cmd2'          - Triggers 'cmd1 || cmd2'
```

Every conditional statement in Bash (`if`, `while`, `until`) does **not** evaluate boolean primitives; it executes a command and tests whether its exit status code is `0`.

---

## 2. Under the Hood: `test` vs. `[` vs. `[[ ... ]]` vs. `(( ... ))`

Understanding the architectural distinction between single brackets, double brackets, and arithmetic evaluation is vital for writing secure, bug-free shell scripts.

```
+------------------------------------------------------------------------------------+
|  1. POSIX Test Binary / Builtin: [ expr ]                                          |
|  - Parsed as a regular command name '[' with required closing argument ']'         |
|  - Subject to Word Splitting and Pathname Expansion (Globbing)                     |
|  - Requires manual quoting of all variable expansions                              |
+------------------------------------------------------------------------------------+
                                         │
                                         ▼ (Bash Enhancement)
+------------------------------------------------------------------------------------+
|  2. Bash Compound Keyword: [[ expr ]]                                              |
|  - Parsed directly by the shell grammar AST parser (Not a command invocation)      |
|  - Word splitting and pathname expansion are automatically DISABLED inside [[ ]]   |
|  - Supports Regular Expressions (=~) and Glob Pattern Matching (==)                |
|  - Enables native logical operators (&&, ||) instead of -a and -o                  |
+------------------------------------------------------------------------------------+
                                         │
                                         ▼ (Arithmetic Evaluation)
+------------------------------------------------------------------------------------+
|  3. Arithmetic Compound: (( expr ))                                                |
|  - Evaluates C-style integer math and relational operators (>, <, >=, <=, ==, !=)   |
|  - Returns exit status 0 if expression evaluates non-zero, exit status 1 if zero   |
+------------------------------------------------------------------------------------+
```

### Side-by-Side Comparison Matrix

| Feature | `test` / `[ ... ]` | `[[ ... ]]` (Bash Keyword) | `(( ... ))` (Arithmetic) |
| :--- | :--- | :--- | :--- |
| **Parser Type** | External Binary / Built-in | Shell Grammar Keyword | Arithmetic Evaluator |
| **Word Splitting** | Yes (Must quote `"$VAR"`) | No (Safe unquoted) | No (Arithmetic variables) |
| **Globbing Expansion**| Yes (Hazardous) | No | No |
| **Regex Matching** | No | Yes (`=~`) | No |
| **Logical AND** | `-a` | `&&` | `&&` |
| **Logical OR** | `-o` | `\|\|` | `\|\|` |
| **Relational Ops** | `-eq`, `-lt`, `-gt` | `-eq`, `-lt`, `-gt` | `==`, `<`, `>`, `<=`, `>=` |
| **String Ops** | `=`, `!=` | `==`, `!=`, `<`, `>` | N/A |

---

## 3. Comprehensive Operator Taxonomy

### Integer Comparison vs. String Comparison

| Evaluation Goal | Integer Operator (inside `[` or `[[`) | Arithmetic (inside `(( ))`) | String Operator (inside `[[`) |
| :--- | :--- | :--- | :--- |
| Equal | `-eq` | `==` | `==` or `=` |
| Not Equal | `-ne` | `!=` | `!=` |
| Less Than | `-lt` | `<` | `<` (lexicographical) |
| Less or Equal | `-le` | `<=` | N/A |
| Greater Than | `-gt` | `>` | `>` (lexicographical) |
| Greater or Equal | `-ge` | `>=` | N/A |

### Unary File System Operators

```
                          File Inode / Path Query
                                     │
      ┌───────────────┬──────────────┼──────────────┬───────────────┐
      ▼               ▼              ▼              ▼               ▼
 -e <path>       -f <path>      -d <path>      -s <path>       -L <path>
Exists (Any)   Regular File   Directory File  Size > 0 bytes  Symbolic Link
      │               │              │              │               │
      ├───────────────┴──────────────┴──────────────┴───────────────┤
      ▼                                                             ▼
 -r <path> (Read permission)                                   -x <path> (Execute permission)
 -w <path> (Write permission)                                  -O <path> (Owned by effective UID)
```

| Operator | Evaluates to True If | Common DevOps Use Case |
| :--- | :--- | :--- |
| `-e path` | Target path exists on filesystem. | Checking if a resource exists before processing |
| `-f path` | Target is a regular file (not directory, socket, or device node). | Validating application config file presence |
| `-d path` | Target is an existing directory. | Validating backup/destination paths |
| `-s path` | File exists and has a size greater than 0 bytes. | Verifying log/download payloads are not empty |
| `-x path` | File exists and has execute permissions for current user. | Verifying binary before invocation |
| `-r path` / `-w path` | Current user has read/write permissions. | Validating access rights |
| `-z string` | String operand length is zero (Empty string). | Checking for unset/missing arguments |
| `-n string` | String operand length is non-zero (Populated string). | Validating required inputs |

---

## 4. Regular Expressions & `BASH_REMATCH`

Bash supports Extended Regular Expression (ERE) pattern matching natively inside `[[ ... =~ ... ]]`.

```
Target String: "agent_node_042.production.internal:9092"
Regex Pattern: ^([a-z_]+)_([0-9]+)\.([a-z]+)\.([a-z]+):([0-9]+)$
                             │
                             ▼ Matches successfully
           Captured Substrings in BASH_REMATCH Array:
           BASH_REMATCH[0] = "agent_node_042.production.internal:9092" (Full Match)
           BASH_REMATCH[1] = "agent_node"
           BASH_REMATCH[2] = "042"
           BASH_REMATCH[3] = "production"
           BASH_REMATCH[4] = "internal"
           BASH_REMATCH[5] = "9092"
```

### Crucial Regex Rule
Never quote the regex expression pattern itself inside `[[ $val =~ "pattern" ]]`. Quoting the right-hand side forces Bash to treat all characters (including `^`, `*`, `+`, `()`) as **literal strings**, disabling regex engine compilation.

---

## 5. Common Pitfalls & Edge Cases

1. **Unquoted Strings in Single Brackets (`[ ... ]`)**:
   ```bash
   NAME=""
   [ $NAME = "alice" ]   # Expands to: [ = "alice" ] -> Syntax Error: unary operator expected!
   [[ $NAME == "alice" ]] # Safe: Keyword prevents grammar breakage
   ```

2. **Accidental File Redirection via `<` or `>` in `[ ... ]`**:
   ```bash
   [ 5 > 2 ] # Creates an empty file named "2" in the current directory! (Parsed as redirection)
   [[ 5 > 2 ]] # Compares lexicographically ("5" > "2")
   (( 5 > 2 )) # Compares numerically (5 > 2 -> True)
   ```
