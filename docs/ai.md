# AI Project Guide

## Repository Map

- Root binary crate: `alire.toml`, `posix_tools.gpr`, `src/posix-tools.adb`.
- Shared library crate: `common/alire.toml`, `common/posix_tools_common.gpr`,
  `common/src`.
- Command crates: `tools/<command>/alire.toml`,
  `tools/<command>/posix_tools_<command>.gpr`, `tools/<command>/src/<command>.adb`.
- Tests and tooling crate: `tests/alire.toml`, `tests/posix_tools_tests.gpr`,
  `tests/src`.
- Human documentation: `docs`.
- Generated release metadata: `generated`.

## Package Map

- `Posix_Tools.Commands.*` contains command implementations.
- `Posix_Tools.Commands.Contexts` is the command service boundary.
- `Posix_Tools.Commands.File_Helpers` contains shared file and line helpers.
- `Posix_Tools.Host_Adapters.*` is the only project layer that may wrap
  hostkit for production platform behavior.
- `Posix_Tools.Localization` is the narrow adapter over `messages`.
- `Posix_Tools.Presentation` is the narrow adapter over `terminal_styles`.
- `Posix_Tools.Streams.*` contains byte, line, and counting helpers.
- `Posix_Tools.Text.*` contains UTF-8 decoding and versioned Unicode
  classification policy.
- `Test_Contexts` provides deterministic command contexts for AUnit tests.

## Dependency Rules

- Command crates depend only on `posix_tools_common`.
- The root crate depends only on `posix_tools_common`.
- `posix_tools_common` depends on `hostkit`, `messages`, and
  `terminal_styles`; it must not depend on `aunit` or `project_tools`.
- The tests crate depends on `posix_tools_common`, `aunit`, and
  `project_tools`.
- No command crate may depend on another command crate.

## Allowed Imports

- Command wrappers may import the command package and
  `Posix_Tools.Host_Adapters.Run_Command`.
- Command implementations may import shared `Posix_Tools` units.
- Production host integration belongs under `Posix_Tools.Host_Adapters`.
- Tests may import AUnit, `Test_Contexts`, and command packages.
- Ada project tooling lives in `tests/src/posix_tools_tests.adb` and uses
  `project_tools`.

## Prohibited Imports

- Command implementations must not import `Hostkit`, `Messages`,
  `Terminal_Styles`, `AUnit`, or `Project_Tools` directly.
- Command wrappers must not import Ada services directly, perform I/O, parse
  options, or read `Ada.Command_Line`.
- Help and root command rendering must not import `Terminal_Styles` directly.
- Command algorithms must not read global standard input directly.

## Project Invariants

- Add commands as binary subcrates under `tools/<command>`.
- Keep executable mains thin.
- Put shared behavior in `posix_tools_common`.
- Keep POSIX command behavior separate from the non-POSIX root executable.
- Do not route command data output through styling.
- Keep byte-oriented data paths binary preserving.
- Keep UTF-8 decoding and Unicode classification isolated from command
  algorithms so future locale-aware behavior can replace the policy.
- Keep per-run command state local to `Run` or helper calls, not package-level
  mutable variables.
- Preserve `--posix-tools-identify` as a sole-argument internal operation.

## Command Workflow

1. Add the command descriptor to `Posix_Tools.Command_Inventory`.
2. Add the command package under `common/src/posix_tools-commands-*`.
3. Add a thin wrapper crate under `tools/<command>`.
4. Add command help and diagnostics through message identifiers.
5. Add AUnit command tests and register them in `Command_Tests.Suite`.
6. Add requirement and regression rows in `generated`.
7. Regenerate package metadata with `posix_tools_tests package`.
8. Run `posix_tools_tests check` and `posix_tools_tests release-check`.

## Test Requirements

- Use `Test_Contexts.Capturing_Context` for deterministic command tests.
- Use byte-for-byte output assertions for command data.
- Use `test --suite command` for all command tests and
  `test --suite <command>` for one command.
- Use `test --suite locale` for locale-dependent help and diagnostics.
- Keep regressions mapped in `generated/regressions.csv`.

## Localization Rules

- Help and diagnostics go through `Posix_Tools.Localization`.
- Command data output is not localized.
- Command names, option spellings, and pathnames are not translated.
- Unknown locales must fall back without leaking message identifiers.

## Styling Rules

- Only `Posix_Tools.Presentation` may call `terminal_styles`.
- Help and root headings may be styled.
- Copied data, counts, pathnames, identity output, and normal `true`/`false`
  behavior must remain unstyled.

## Resource Policies

- Commands do not close process-owned standard streams.
- `cat`, `head`, `tail`, and `wc` treat `-` as standard input.
- Repeated `-` is valid and does not rewind input.
- Output failure returns operational failure without misreporting it as input
  failure.
- `tail` line state and `head` prefix state are per call; `tail -c` still uses
  an in-memory ring and has a recorded spill-storage deviation.

## Completion Criteria

- `tests/bin/posix_tools_tests check` must pass.
- `tests/bin/posix_tools_tests release-check` must pass.
- Package manifest and release checksums must be current.
- All command wrappers must stay thin.
- Requirements and regressions must reference existing tests.

## Rejected Architectures

- A monolithic command dispatcher for POSIX utilities.
- A plugin system for V1 commands.
- Direct Hostkit use from command algorithms.
- Direct terminal styling in command data paths.
- Shell, Python, JavaScript, Make, CMake, or PowerShell project tooling.
