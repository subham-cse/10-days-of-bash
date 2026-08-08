# Day 08: Arrays, Arithmetic Expansion, and Advanced String Operations

## Overview & The Bash Data Manipulation Architecture

Bash provides three core mechanisms for in-memory data processing:
1. **Indexed Arrays & Associative Arrays (Hash Maps)**: Linear lists and key-value stores.
2. **Arithmetic Evaluation Engine (`$(( ... ))`)**: 64-bit signed integer math directly executed in the C runtime without subshell overhead.
3. **Parameter Expansion Transformations**: Native, high-performance substring extraction, pattern removal, search-and-replace, and default fallbacks performed directly by the parser.

```
                  +--------------------------------------------------+
                  |            Raw Variable / Parameter              |
                  |           "  /var/log/nginx/access.tar.gz  "     |
                  +--------------------------------------------------+
                                           |
               +---------------------------+--------------------------+
               | Prefix Stripping (#, ##)                             | Suffix Stripping (%, %%)
               v                                                      v
  ${file#*/}  --> "var/log/nginx/access.tar.gz"         ${file%.*}  --> "/var/log/nginx/access.tar"
  ${file##*/} --> "access.tar.gz"                       ${file%%.*} --> "/var/log/nginx/access"
```

---

## 1. Array Types & Operations Matrix

| Operation | Indexed Array Syntax (`declare -a`) | Associative Array Syntax (`declare -A`) | Notes & Complexity |
| :--- | :--- | :--- | :--- |
| **Declaration** | `declare -a arr=("a" "b" "c")` | `declare -A map=([k1]="v1" [k2]="v2")` | Associative **requires** `declare -A` |
| **Element Read** | `${arr[0]}` | `${map["k1"]}` | $O(1)$ direct index / hash lookup |
| **Element Append** | `arr+=("d" "e")` | `map["k3"]="v3"` | Expands dynamic array buffer |
| **All Values** | `"${arr[@]}"` | `"${map[@]}"` | Expands to list of quoted elements |
| **All Keys/Indices**| `"${!arr[@]}"` | `"${!map[@]}"` | Returns `0 1 2` or key strings |
| **Element Count** | `${#arr[@]}` | `${#map[@]}` | Number of populated slots |
| **Array Slicing** | `"${arr[@]:offset:length}"` | *N/A (Keys are unordered)* | Extracts subset slice |
| **Element Unset** | `unset 'arr[1]'` | `unset 'map["k1"]'` | Creates sparse array in indexed mode |

---

## 2. Advanced Parameter Expansion Catalog

Parameter expansions are evaluated by the shell parser natively, avoiding expensive forks or external subshells (`sed`/`awk`/`cut`).

```
String: "production-app-server-01.us-east-1.internal.net"
```

| Expansion Pattern | Transformation Logic | Evaluated Output Example |
| :--- | :--- | :--- |
| `${var#pattern}` | Delete **shortest** match of `pattern` from **beginning** | `app-server-01.us-east-1...` (if pattern `*-`) |
| `${var##pattern}` | Delete **longest** match of `pattern` from **beginning** | `01.us-east-1.internal.net` (if pattern `*-`) |
| `${var%pattern}` | Delete **shortest** match of `pattern` from **end** | `...internal` (if pattern `.*`) |
| `${var%%pattern}` | Delete **longest** match of `pattern` from **end** | `production-app-server-01` (if pattern `.*`) |
| `${var/find/replace}` | Replace **first** match of `find` with `replace` | Replaces first instance |
| `${var//find/replace}`| Replace **all** matches of `find` with `replace` | Replaces every instance |
| `${var:-default}` | If `var` is unset or null, return `default` | Safe fallback without modifying variable |
| `${var:=default}` | If `var` is unset or null, set `var=default` and return it | In-place default initialization |
| `${var:?error_msg}` | If `var` is unset or null, print `error_msg` and exit | Critical configuration assertions |
| `${#var}` | Length of string stored in `var` | Integer character count |

---

## 3. Arithmetic Operations & Integer Mechanics: `$(( ... ))`

Bash arithmetic utilizes 64-bit signed integers ($[-2^{63}, 2^{63}-1]$). Variables inside `$(( ))` do not strictly require the `$` prefix.

```bash
a=15
b=4

sum=$(( a + b ))        # 19
diff=$(( a - b ))       # 11
prod=$(( a * b ))       # 60
quot=$(( a / b ))       # 3 (Truncated integer division)
rem=$(( a % b ))        # 3 (Modulo remainder)
pow=$(( a ** 2 ))       # 225 (Exponentiation)

# Compound operations & bitwise shifts
(( a += 5 ))            # Modifies variable in-place (a=20)
flags=$(( 1 << 3 ))     # Bitwise left shift (8)
```

```
                        +----------------------------+
                        | Arithmetic Evaluation Path |
                        +----------------------------+
                                      |
                     [ Is Floating-Point Needed? ]
                               /              \
                             (No)            (Yes)
                              /                  \
              +-------------------------+   +-------------------------+
              | Bash Native $(( ... ))  |   | External Engine: `bc`   |
              | 64-bit Signed Integer   |   | bc -l <<< "scale=2; 5/2"|
              +-------------------------+   +-------------------------+
```

---

## 4. Under the Hood: Memory Structure of Arrays & Hash Tables

In Bash's underlying C source code (`variables.c`, `array.c`, `assoc.c`):
* **Indexed Arrays (`ARRAY`)**: Implemented as a doubly-linked circular list of element structures (`ARRAY_ELEMENT`). Sparse arrays skip unassigned indices without allocating empty memory slots.
* **Associative Arrays (`HASH_TABLE`)**: Implemented as a dynamically resizing hash table with bucket chaining. Keys are hashed using a variant of the Bernstein hash function.
* **Parsing Cost**: Native string expansions (`${var##*/}`) execute entirely in RAM within the main process thread, outperforming `basename "$var"` by over 100x in iterative loops due to zero process fork/execve overhead.

---

## 5. Common Pitfalls & Edge Cases

1. **Floating-Point Calculations**: Bash cannot natively evaluate `3.14 * 2`. Attempting `$(( 3.14 * 2 ))` produces a syntax error. Use `bc`, `awk`, or `printf` for floating-point math.
2. **Empty Array Expansions with `set -u`**: In older Bash versions (< 4.4), expanding an empty array `"${empty_arr[@]}"` triggers an `unbound variable` error under `set -u`.
   * *Mitigation*: Use `"${empty_arr[@]:-}"` or check length `${#empty_arr[@]}` prior to iteration.
3. **Word Splitting when Appending Unquoted Strings**:
   ```bash
   arr+=($multi_word_string)    # Splits on spaces into multiple array elements!
   arr+=("$multi_word_string")  # Preserves single element cleanly.
   ```
4. **Leading Zero Octal Trap**: Numbers with a leading zero are interpreted as octal. `08` or `09` causes `invalid octal number` error.
   * *Mitigation*: Force base 10 using `10#$var` (e.g. `$(( 10#08 + 1 ))`).
