# explore

## Name

explore - visual file manager for bracke-terminal

## Synopsis

`explore [directory]`

## Description

`explore` is a full-screen, keyboard- and mouse-driven file manager. It takes over the terminal's alternate screen,
shows the directory it was given (or the current directory), and hands the terminal back as it found it when it ends.

`explore` runs only inside bracke-terminal. At start-up it asks the terminal to identify itself and refuses to run in
any terminal that does not.

This release is the foundation milestone: it starts, identifies the terminal, draws its frame, follows resizes, and
quits on `q`. Navigation, file operations, and previews follow in later milestones.

## Operands

`directory` is the directory to start in. It defaults to the current directory. At most one operand is accepted.

## Options

No command options. Common project options such as `--help`, `--version`, and the internal identity option are
recognized at the command boundary.

## Standard Input

Must be a terminal. It is read in raw mode for keys, mouse reports, resize reports, and the terminal's answers to
explore's queries.

## Standard Output

Must be the same terminal. It receives the screen explore draws and its queries to the terminal.

## Standard Error

Diagnostics are localized through messages and written after the terminal has been handed back.

## Exit Status

`0` when the user quits, `1` when the operand is not a directory, standard input or output is not a terminal, the
terminal cannot be put into raw mode, the terminal does not identify itself as bracke-terminal, or output fails, `2` for
invalid usage, `128` plus the signal number when a terminate or hangup signal ends the session, and `125` for
unexpected internal failures at the command boundary.

## Behavioral Details

At start-up `explore` saves the terminal's settings, puts it into raw mode, and sends the identity query
`OSC 7701 ; q ST` followed by a primary device attributes request. bracke-terminal answers the first with
`OSC 7701 ; v=<version> ; caps=<capability>,... ST`; every terminal answers the second. When the device attributes
arrive without an identity answer before them, or nothing arrives within half a second, the terminal is not
bracke-terminal and `explore` restores it and exits with a diagnostic. Unknown keys and capability names in the answer
are ignored, so the terminal and `explore` can each grow without breaking the other.

Once identified, `explore` switches to the alternate screen and asks for SGR mouse reports, focus reports, bracketed
paste, in-band resize reports, and disambiguated keys. Each frame is sent as one synchronized update.

On every way out -- quitting, a terminate or hangup signal, failing output, or an unexpected internal failure --
`explore` leaves the alternate screen, turns those reports off again, restores the saved terminal settings, and puts
back the signal dispositions it changed. A terminate or hangup signal that was ignored when `explore` started stays
ignored.

Inside tmux (`TMUX` set in the environment), the identity query and every sequence meant for bracke-terminal itself
are wrapped in tmux's DCS passthrough, which requires `set -g allow-passthrough on` in tmux. Whether tmux forwards the
terminal's answers back to the pane is a validation item of a later milestone.

## Locale Behavior

Interface text, help, and diagnostics are locale-dependent. Pathnames are shown as they are.

## Implementation-Defined Choices

The identity handshake waits at most 500 milliseconds. A lone ESC byte is taken as the Escape key after 100
milliseconds without further input. Terminals that do not report resizes in band are measured again when the window
change signal arrives.

## Extensions

`explore` is a project extension command, not a POSIX utility. The command supports project-wide help, version, and
identity operations.

## Examples

`explore`

`explore ~/projects`

## Conformance Status

Project extension; not a POSIX utility.

## Known Limitations

Only bracke-terminal is supported, by design. Directory listings, file operations, previews, tabs, search, and
configuration are not yet implemented.
