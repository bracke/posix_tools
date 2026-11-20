# rg

`rg` is the native Ada recursive-search extension for `posix_tools`. It uses
the sibling `regexp` crate for all pattern matching and `Version.Ignore` from
`versionlib` for Git-compatible ignore evaluation.

The compatibility reference is ripgrep 15.2.0. The implementation is under
active development; unsupported search behavior is rejected explicitly.

Line-oriented searches can emit ripgrep-compatible JSON Lines with `--json`,
including match/context events, byte offsets, submatches, replacement fields,
per-file end events, and a final statistics summary. Non-UTF-8 values are
represented with the schema's base64 `bytes` form. NUL-delimited searches
retain escaped record terminators in JSON payloads while events remain
LF-delimited. Multiline matches use complete touched-record blocks with
block-relative submatch offsets.

Content search uses a bounded native Ada task pool. `-j NUM` and `--threads NUM`
select an approximate worker count, with zero choosing the host CPU count.
Recursive discoveries, multiple explicit files, and independent directory
roots share protected work queues. Compiled expressions are shared read-only,
cursors remain worker-local, and a protected emission gate writes complete file
results in operand and discovery order. Operand sets containing standard input
remain sequential.

ANSI output supports named colors, indexed values from 0 through 255, and RGB
triples through iterative `--colors` rules. Automatic terminal and `NO_COLOR`
decisions use `terminal_styles`; rendering constructs each result's SGR prefix
locally and never changes the process-wide color policy from worker tasks.

Input decoding is streaming and bounded. `-E` and `--encoding` implement all 40
decoders and all 228 labels from the WHATWG table used by ripgrep 15.2.0's
`encoding_rs` 0.8.35 dependency, including the single-byte, East Asian,
replacement, and x-user-defined families. Decoded byte positions remain
consistent across text and JSON output, malformed input follows the reference's
replacement/reconsumption rules, and unknown labels are rejected explicitly.

Case-insensitive regex and fixed-string search use the complete Unicode 16.0
simple-fold equivalence table pinned by ripgrep 15.2.0. Smart case uses the
Unicode `Uppercase` property, including non-ASCII and astral characters.
Whole-word matching and `\w` use the corresponding Unicode word table, and
property escapes expose the complete `regex-syntax` 0.8.11 Unicode inventory.
Invalid UTF-8 bytes are nonmatching barriers; searching resumes after them.
Scoped `(?-u:...)` groups switch to byte mode when raw invalid bytes must
participate in a match, and nested `(?u:...)` groups restore Unicode matching.
Character-mode transitions preserve byte offsets across captures and output.

The default bounded engine limits are 1024 pattern bytes, 2048 states, one
million match steps, and a 16 KiB streaming window. Multiline command input has
a separate explicit 64 MiB bound, including NUL-delimited multiline records.

`--debug` and `--trace` provide structured standard-error diagnostics for
configuration, regex compilation, ignore-rule provenance, traversal decisions,
binary detection, and per-file search strategy without altering result output.

Build from this directory with:

```sh
alr build
```
