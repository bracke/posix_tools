# Compatibility

This executable follows the traditional POSIX `awk` command-line workflow where
`awklib` exposes the needed behavior. It does not claim complete POSIX
conformance. The CLI does not implement a second AWK parser, evaluator, regular
expression engine, field engine, source rewriter, or custom record loop.

Accepted limitations are tracked in the Ada registry `Awk_CLI.Compatibility`.
Each entry lists the affected area, status, source of limitation, and the
closest current test reference.

No current entries are classified as unsupported for the resolved `awklib`
version. Historical limitation IDs remain in the registry as reviewed
`Supported` entries so dependency updates can be audited deliberately.

| ID | Area | Status | Source | Test reference | Description |
| --- | --- | --- | --- | --- | --- |
| AWK-COMPAT-REGEX-001 | regular expressions | Supported | resolved awklib 0.1.0 behavior | awk process : process filter expression smoke | Regular-expression integration follows resolved awklib behavior. |
| AWK-COMPAT-GETLINE-001 | getline | Supported | resolved awklib 0.1.0 behavior | awk context : context main getline from BEGIN | Main-input `getline` from `BEGIN` is handled by resolved awklib. |
| AWK-COMPAT-GETLINE-002 | getline | Supported | resolved awklib 0.1.0 behavior | awk process : process command getline | `command | getline` is parsed and evaluated by awklib; the CLI supplies only the host command runner requested through the awklib callback. |
| AWK-COMPAT-UTF8-001 | encoding | Supported | resolved awklib 0.1.0 behavior | awk compatibility : compatibility registry | Malformed UTF-8 no longer requires a CLI compatibility limitation. |
| AWK-COMPAT-PRINTF-001 | output formatting | Supported | resolved awklib 0.1.0 behavior | awklib suite : Test_Printf_Flags | `printf %c` field-width behavior follows resolved awklib. |
| AWK-COMPAT-ASSIGNMENT-001 | command line | Supported | resolved awklib 0.1.0 behavior | awk process : process runtime assignment positions | Positional runtime assignments are represented at the CLI boundary. |
| AWK-COMPAT-REDIRECTION-001 | redirection | Supported | resolved awklib 0.1.0 behavior | awk process : process append redirection | Append redirection intent is exposed through awklib streaming callbacks. |

An `awklib` dependency update requires rebuilding, running all tests, reviewing
upstream behavior, updating this registry and document, and changing test
expectations only where the resolved interpreter behavior actually changes.
