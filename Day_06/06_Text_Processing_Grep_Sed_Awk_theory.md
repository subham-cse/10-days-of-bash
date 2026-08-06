# Day 06: Text Processing with Grep, Sed, Awk, and Cut

## Overview & The Unix Text Processing Philosophy

In Unix-like operating systems, plain text is the universal interface. Tools adhere to the Unix philosophy: write programs that do one thing well and compose them via standard streams (`stdin`, `stdout`, `stderr`). Mastering text stream filtering, pattern matching, substitution, and columnar transformation transforms the terminal into an expressive database engine.

```
       +-------------+             +-------------+             +-------------+
stdin  |    grep     |   stdout    |     sed     |   stdout    |     awk     |  stdout
------>|  (Filter)   |============>| (Transform) |============>| (Aggregate) |--------->
       +-------------+ pipe (FIFO) +-------------+ pipe (FIFO) +-------------+
```

---

## 1. Tool Matrix & Architectural Comparison

| Dimension | `grep` | `sed` (Stream Editor) | `awk` (Pattern Scanning & Processing) | `cut` |
| :--- | :--- | :--- | :--- | :--- |
| **Primary Domain** | Line-based filtering & regex search | Non-interactive stream editing & substitution | Full Turing-complete tabular data processing | Byte/character/field columnar extraction |
| **Execution Model** | Line scanning against NFA/DFA regex engine | Cycle: Pattern Space $\leftrightarrow$ Hold Space | Record/Field cycle (`BEGIN` $\to$ records $\to$ `END`) | Offset-based single-pass delimiter scan |
| **Regex Support** | Basic (BRE), Extended (ERE `-E`), Perl (PCRE `-P`) | Basic (BRE default), Extended (ERE `-E` / `-r`) | Extended (ERE natively in `/pattern/`) | None (delimiters & fixed indices only) |
| **State Retention** | Stateless across lines | Dual-buffer memory (Pattern Space / Hold Space) | Associative arrays, variables, counters | Stateless |
| **Performance** | Extremely fast (Boyer-Moore & Aho-Corasick) | Fast stream transformation | Moderately fast; full interpreter overhead | Ultra fast for raw delimiter slicing |

---

## 2. In-Depth Mechanics: Grep (Global Regular Expression Print)

### Regular Expression Engines
`grep` searches input files or `stdin` for lines matching a pattern.

* **BRE (Basic Regular Expressions)**: Default in POSIX `grep`. Metacharacters `(`, `)`, `{`, `}`, `+`, `?` require backslash escaping (`\+`, `\{1,3\}`).
* **ERE (Extended Regular Expressions - `-E` or `egrep`)**: Metacharacters retain special meaning without escaping.
* **PCRE (Perl Compatible Regular Expressions - `-P`)**: Supports lookarounds `(?=...)`, non-greedy quantifiers `.*?`, and character classes `\d`, `\s`, `\w`.

### Key Grep Flags
* `-E`: Interpret pattern as Extended Regular Expression (ERE).
* `-i`: Case-insensitive search.
* `-v`: Invert match (select non-matching lines).
* `-o`: Output only matched segments (crucial for extraction pipelines).
* `-c`: Suppress normal output; print match count per input.
* `-n`: Prefix output with 1-based line numbers.
* `-H` / `-h`: Print filename header (`-H`) or suppress filename header (`-h`).
* `-q`: Quiet mode; exit immediately with code `0` on first match, `1` if not found.

```bash
# Extract only IPv4 addresses from an access log
grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' access.log

# Count failed SSH login attempts
grep -c "Failed password" /var/log/auth.log
```

---

## 3. In-Depth Mechanics: Sed (Stream Editor)

`sed` reads input line-by-line into the **Pattern Space**, applies ordered editing commands, and flushes to `stdout` unless suppressed by `-n`.

```
                  +-----------------------------------+
                  |            Input Stream           |
                  +-----------------------------------+
                                    |
                                    v (Read Line)
                      +---------------------------+
                      |       Pattern Space       | <---+
                      +---------------------------+     |
                                    |                   | sed script / commands
                                    v                   | (s/find/replace/g)
                      +---------------------------+     |
                      |        Hold Space         | ----+ (Hold buffer exchange)
                      +---------------------------+
                                    |
                                    v (Auto-print if not -n)
                  +-----------------------------------+
                  |           Output Stream           |
                  +-----------------------------------+
```

### Substitution Syntax: `s/regex/replacement/flags`
* Delimiters: Standard `/`, but any character (`#`, `|`, `@`, `,`) can serve as delimiter to avoid "leaning toothpick syndrome" (e.g., `s#/var/log#/opt/logs#g`).
* Flags:
  * `g`: Global (replace all occurrences per line, not just first).
  * `i` or `I`: Case-insensitive match.
  * `p`: Print pattern space if substitution succeeded (used with `sed -n`).
  * `w <file>`: Write matched and modified lines to file.
* Backreferences: `\1`, `\2` refer to captured groups `(...)` in ERE (`sed -E`).

```bash
# In-place file modification with backup (.bak)
sed -i.bak 's/DEBUG_MODE=true/DEBUG_MODE=false/g' /etc/app.conf

# Delete blank lines or comment lines
sed -E '/^[[:space:]]*($|#)/d' config.ini

# Swap columns delimited by colon
sed -E 's/^([^:]+):(.*)$/\2 -> \1/' input.txt
```

---

## 4. In-Depth Mechanics: Awk

`awk` operates on records (lines, delimited by `RS`) and fields (tokens, delimited by `FS`).

### Built-in Variables Table
| Variable | Meaning | Default Value |
| :--- | :--- | :--- |
| `FS` | Field Separator regex | `[ \t\n]+` (Whitespace) |
| `OFS` | Output Field Separator | `" "` (Single space) |
| `RS` | Record Separator | `\n` (Newline) |
| `ORS` | Output Record Separator | `\n` (Newline) |
| `NR` | Total Number of Records read across all inputs | Cumulative integer |
| `FNR` | Number of Records in current file | Per-file integer |
| `NF` | Number of Fields in current record | Count of columns in line |
| `$0` | Entire current record raw text | Full line string |
| `$1..$NF` | Specific field values indexed 1 to NF | Column token string |

### The Awk Program Lifecycle
```
BEGIN { ... }         # Executed once before processing any input records
/pattern/ { ... }     # Executed on every record matching pattern
{ ... }               # Executed unconditionally on every record
END { ... }           # Executed once after all records and files are exhausted
```

```bash
# Column aggregation & arithmetic mean
awk '{ sum += $5; count++ } END { if (count > 0) printf "Avg: %.2f KB\n", sum/count/1024 }' access.log

# Group by status code (Associative Array)
awk '{ status[$9]++ } END { for (code in status) printf "%s: %d\n", code, status[code] }' access.log
```

---

## 5. Under the Hood: Streaming Engines & Pipeline Buffering

When piping `grep | sed | awk`, the Linux kernel allocates FIFO ring buffers (typically 64 KB per pipe). 

```
[Producer Process] ---> [Kernel Pipe Buffer (64KB)] ---> [Consumer Process]
```

* **Standard I/O Buffering Modes**:
  * **Unbuffered (`_IONBF`)**: Flushed byte-by-byte (default for `stderr`).
  * **Line-buffered (`_IOLBF`)**: Flushed on `\n` (default when connected to a terminal/TTY).
  * **Block-buffered (`_IOFBF`)**: Flushed only when 4096 / 8192 bytes accumulate (default when writing to a pipe or file).
* **Fixing Pipeline Lag**: When streaming live logs (`tail -f | grep | sed`), buffering can delay output.
  * Use `grep --line-buffered`
  * Use `sed -u` / `sed --unbuffered`
  * Use `stdbuf -oL -eL awk ...`

---

## 6. Common Pitfalls & Edge Cases

1. **Sed Delimiter Collisions**: Modifying file paths `s//usr/bin//usr/local/bin/` causes syntax errors. Always switch delimiter: `s#/usr/bin#/usr/local/bin#g`.
2. **Awk Field Separator Multi-character Gotchas**: In `awk -F':'`, `$1` on empty fields `::` is empty string. In default whitespace `FS`, consecutive spaces/tabs are treated as a single delimiter.
3. **BSD vs GNU `sed -i` Incompatibility**:
   * GNU `sed`: `sed -i 's/a/b/' file` (backup extension optional).
   * macOS / BSD `sed`: `sed -i '' 's/a/b/' file` (empty quotes mandatory for no backup).
4. **Grep Non-Zero Exit Code on Empty Match**: `grep` returns exit status `1` when no match is found. Under `set -e`, this immediately terminates the script. Protect with `grep 'pattern' file || true` or capture exit status.
