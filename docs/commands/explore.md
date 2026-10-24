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

The screen has three panes: the parent of the current directory on the left, the current directory in the middle, and
on the right a preview of the selected entry -- the listing of a directory, or the mode, size, time, and link target of
anything else. Below 80 columns the parent pane is left out, and below 50 the preview too. The top line shows the
current directory; the status line shows the selected entry's mode, owner, size, and modification time, its position,
and any filter or pending prefix key.

File operations, content previews, tabs, and search follow in later milestones.

### Keys

| Key | Action |
| --- | --- |
| `j`, Down / `k`, Up | move down / up |
| `l`, Right, Enter | enter the selected directory |
| `h`, Left | go up to the parent directory |
| `gg`, Home / `G`, End | first / last entry |
| Ctrl-d / Ctrl-u | half a page down / up |
| Ctrl-f, Page Down / Ctrl-b, Page Up | a page down / up |
| `.` | show or hide entries whose names start with a dot |
| `f` | type a filter: only names containing it, regardless of case, are shown; Enter keeps it, Escape clears it |
| Escape | clear the filter |
| `,n` `,a` `,e` `,s` `,m` `,t` | sort by natural name, name, extension, size, modification time, or kind; the capital letter sorts in reverse |
| `~` | go to the home directory |
| `q` | quit |

The mouse wheel moves the selection. A click in the current pane selects the entry under it, in the parent pane goes
up, and in the preview pane enters the selected directory.

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

Directories are read through the shared `Posix_Tools.File_Operations.Listing` on two worker tasks, away from the
screen, so a large or slow directory never holds up the keyboard. Each pane has one outstanding read at most: moving on
replaces it, a read already running for the replaced request stops at its next entry, and entries that arrive for it
are dropped. The current and parent directories are watched, and re-read when they change, with the selection kept on
the same name. Entries are sorted by natural name by default, with directories first and ASCII case ignored. Only the
cells that changed are redrawn.

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

Only bracke-terminal is supported, by design. File operations, content previews, tabs, search, bookmarks, and
configuration are not yet implemented. Combining characters in names are not drawn. A watched directory is re-read whole
when it changes.
