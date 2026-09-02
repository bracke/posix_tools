# Diagnostics

Expected operational failures are represented as structured diagnostics until
final rendering. Categories include usage, program source, input, output,
interpreter, environment, platform, and internal failures.

Rendered CLI diagnostics use this shape:

```text
awk: error: localized primary message
source-name:line:column
interpreter or host detail
hint: localized hint
```

Source locations are optional and are currently used by CLI-owned diagnostics
when available. Interpreter-provided details are preserved as technical detail
without parsing or rewriting AWK source.

Exit statuses are stable:

| Status | Meaning |
| --- | --- |
| `0` | Success, `--help`, or `--version` |
| `1` | AWK parse or runtime failure |
| `2` | Invalid command-line invocation |
| `3` | Host input/output failure |
| `70` | Unexpected internal software failure |

CLI diagnostics are localized and terminal-control-safe. Untrusted diagnostic
values such as option text, filenames, source names, and interpreter details
escape embedded newlines, carriage returns, tabs, ESC, and other control
characters. AWK standard output and redirected output are never escaped,
localized, styled, prefixed, or reformatted.

Host file diagnostics distinguish open failures from read failures where the
platform adapter can observe the difference. Missing program files and input
files report `open_failed`; files that open but cannot be read report
`read_failed`. Both cases keep exit status `3`.

Styling is produced only through `terminal_styles`. `--color=auto` follows the
resolved `terminal_styles` policy, including `NO_COLOR`, and applies independent
destination-aware terminal detection for standard output and standard error.
