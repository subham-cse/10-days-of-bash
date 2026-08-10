# Day 10: Capstone Project - Enterprise Backup Automation and Log Rotation

## Overview & Archive Architecture

Enterprise backup automation requires combining archiving, lossless compression, storage constraint verification, data integrity validation, retention policy pruning, and manifest generation.

```
+-------------------------------------------------------------------------------+
|                         Enterprise Backup Pipeline                            |
+-------------------------------------------------------------------------------+
|                                                                               |
|  [ Source Directory ]                                                         |
|         |                                                                     |
|         v (Pre-flight Disk & Read Checks)                                     |
|  +--------------+                                                             |
|  |     tar      |  (Concatenates directory tree into 512-byte block stream)   |
|  +--------------+                                                             |
|         | uncompressed tar stream                                             |
|         v                                                                     |
|  +--------------+                                                             |
|  |     gzip     |  (Applies LZ77 + Huffman coding via DEFLATE engine)         |
|  +--------------+                                                             |
|         | .tar.gz byte stream                                                 |
|         v                                                                     |
|  [ Output Archive: /backup/app_backup_20261007_140000.tar.gz ]               |
|         |                                                                     |
|         +---> Integrity Audit (`tar -tzf`)                                    |
|         +---> Retention Pruner (`find -mtime +7 -delete`)                     |
|         +---> Audit Manifest Generation                                       |
+-------------------------------------------------------------------------------+
```

---

## 1. Compression Algorithms & Utility Comparison

| Algorithm / Tool | Extension | Compression Speed | Decompression Speed | Compression Ratio | Memory Overhead | Best Production Fit |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`gzip` (DEFLATE)** | `.tar.gz`, `.tgz` | **Very Fast** | **Ultra Fast** | Moderate (~65-75%) | Very Low (< 1 MB) | Standard default for routine backups & logs |
| **`bzip2` (Burrows-Wheeler)** | `.tar.bz2` | Slow | Moderate | Good (~75-80%) | Moderate (~8 MB) | Legacy systems |
| **`xz` (LZMA2)** | `.tar.xz` | Very Slow | Moderate | **Maximum (~80-90%)** | High (~100-500 MB) | OS distribution ISOs & cold storage |
| **`zstd` (Zstandard)** | `.tar.zst` | **Ultra Fast** | **Ultra Fast** | Excellent (~75-85%) | Low to Moderate | Real-time database and modern log streaming |

---

## 2. Standardized ISO-8601 Date Formatting

Consistent, lexicographically sortable date stamping prevents archive collision and simplifies automated pruning.

```bash
# ISO-8601 Basic (Compact Timestamp)
date +%Y%m%d_%H%M%S        # e.g., 20261007_142530

# ISO-8601 Extended (UTC Standard)
date -u +"%Y-%m-%dT%H:%M:%SZ" # e.g., 2026-10-07T08:55:30Z

# UNIX Epoch Timestamp (Seconds since 1970-01-01)
date +%s                   # e.g., 1791363930
```

---

## 3. Log Rotation Lifecycle & Strategies

Log files grow continuously. Unchecked growth consumes disk storage and degrades read/write I/O performance.

```
+---------------+      Rename / Move       +--------------------+
|  active.log   |  =====================>  |  active.log.1      |
+---------------+                          +--------------------+
        | (Touch / SIGHUP)                           |
        v                                            v (gzip)
+---------------+                          +--------------------+
|  active.log   | (New empty log file)     |  active.log.1.gz   |
+---------------+                          +--------------------+
                                                     |
                                                     v (Age > 7 Days)
                                           +--------------------+
                                           |     Purged / rm    |
                                           +--------------------+
```

### Key Rotation Strategies
1. **Size-Triggered Rotation**: Rotates when file size exceeds a threshold (e.g. 100 MB).
2. **Time-Triggered Rotation**: Rotates at fixed intervals (hourly, daily, weekly via cron).
3. **Copytruncate vs Signal Reload**:
   * `copytruncate`: Copies active log to backup and truncates existing file in-place (potential byte loss during copy).
   * `create` + `kill -HUP`: Moves file and sends signal to daemon to reopen new file descriptor (zero byte loss).

---

## 4. Under the Hood: Tar Block Format & Gzip DEFLATE

* **TAR (Tape Archive) Format**: TAR structures files into contiguous 512-byte blocks. Each file entry begins with a 512-byte header containing POSIX `ustar` metadata (file name, file mode permissions, UID/GID, file size in octal, modification timestamp, checksum, type flag). The archive ends with two consecutive 512-byte blocks filled with null bytes ($1024$ zero bytes).
* **GZIP Compression**: Operates on byte streams using the DEFLATE algorithm combining LZ77 (sliding-window dictionary matching duplicate byte sequences) and Huffman coding (frequency-based variable-length bit encoding).

---

## 5. Defensive Verification Checklist for Production Backups

```
+--------------------------------------------------------------------------+
|                       Pre-Flight Verification                            |
|  [✓] Validate target directory exists and is readable                    |
|  [✓] Calculate required bytes (`du -sb`)                                  |
|  [✓] Verify destination partition has $\ge 1.5\times$ required free space|
|                                                                          |
|                       In-Flight Execution                                |
|  [✓] Execute atomic archive creation (`tar -czf`)                        |
|  [✓] Capture process exit codes under `set -o pipefail`                  |
|                                                                          |
|                       Post-Flight Verification                           |
|  [✓] Test archive stream integrity (`tar -tzf <archive> > /dev/null`)    |
|  [✓] Verify non-zero archive file size (`[[ -s <archive> ]]`)            |
|  [✓] Prune archives violating retention threshold (`find -mtime +7`)     |
|  [✓] Emit signed execution manifest and metrics summary                  |
+--------------------------------------------------------------------------+
```

---

## 6. Common Pitfalls & Edge Cases

1. **Tar Absolute Path Preservation**: Creating archives with absolute paths (`tar -czf b.tar.gz /var/log`) can overwrite root system files during extraction. Always use `-C /var/log .` or relative paths.
2. **Active File Mutation During Tar**: If files change while `tar` is reading them, `tar` exits with code `1` ("file changed as we read it"). Handle exit code 1 appropriately.
3. **Pruning Glob Failures**: Using `rm -rf /backup/*.tar.gz` when no files match can trigger errors under strict mode or delete incorrect files. Use `find` with `-type f` and `-name`.
4. **Insufficient Temporary Disk Space**: In-place archiving without checking `df -k` can lead to disk exhaustion, crashing active databases.
