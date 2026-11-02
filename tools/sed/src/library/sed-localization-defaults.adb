--  English text of every message in share/sed/messages/catalog.txt, as
--  that catalogue gives it once rendered: what a message says when no
--  catalogue can be read or the catalogue lacks it. Keep each entry equal
--  to its "en." line; the tests check that they are.
package body Sed.Localization.Defaults is

   --------------
   -- Template --
   --------------

   function Template (Key : String) return String is
   begin
      if Key = "sed.diagnostic.with_location" then
         return
           "{program}: {location}: {severity}: {message}";
      elsif Key = "sed.diagnostic.without_location" then
         return
           "{program}: {severity}: {message}";
      elsif Key = "sed.diagnostic.detail" then
         return
           "{message} ({detail})";
      elsif Key = "sed.diagnostic.note" then
         return
           "{program}: {location}: {severity}: {message}";
      elsif Key = "sed.diagnostic.severity.error" then
         return
           "error";
      elsif Key = "sed.diagnostic.severity.warning" then
         return
           "warning";
      elsif Key = "sed.diagnostic.severity.information" then
         return
           "note";
      elsif Key = "sed.location.path" then
         return
           "{path}";
      elsif Key = "sed.location.path_line" then
         return
           "{path}:{line}";
      elsif Key = "sed.location.path_line_column" then
         return
           "{path}:{line}:{column}";
      elsif Key = "sed.location.expression" then
         return
           "command line expression {index}";
      elsif Key = "sed.location.expression_line" then
         return
           "command line expression {index}:{line}";
      elsif Key = "sed.location.expression_line_column" then
         return
           "command line expression {index}:{line}:{column}";
      elsif Key = "sed.error.option.unknown" then
         return
           "unrecognized option {option}";
      elsif Key = "sed.error.option.missing_argument" then
         return
           "option {option} requires an argument";
      elsif Key = "sed.error.option.invalid_argument" then
         return
           "invalid argument {value} for option {option}";
      elsif Key = "sed.error.script.missing" then
         return
           "no script specified";
      elsif Key = "sed.error.script.open_failed" then
         return
           "cannot read script file";
      elsif Key = "sed.error.script.read_failed" then
         return
           "error reading script file";
      elsif Key = "sed.error.script.syntax" then
         return
           "invalid sed script";
      elsif Key = "sed.error.regexp.invalid" then
         return
           "invalid regular expression";
      elsif Key = "sed.error.script.undefined_label" then
         return
           "undefined label";
      elsif Key = "sed.error.script.duplicate_label" then
         return
           "duplicate label";
      elsif Key = "sed.error.input.open_failed" then
         return
           "cannot read input file";
      elsif Key = "sed.error.input.read_failed" then
         return
           "error reading input file";
      elsif Key = "sed.error.output.standard_failed" then
         return
           "error writing to standard output";
      elsif Key = "sed.error.output.open_failed" then
         return
           "cannot create output file";
      elsif Key = "sed.error.output.write_failed" then
         return
           "error writing output file";
      elsif Key = "sed.warning.resource.read_failed" then
         return
           "error reading the file named by an r command";
      elsif Key = "sed.error.runtime.execution_failed" then
         return
           "script execution failed";
      elsif Key = "sed.error.runtime.resource_exhausted" then
         return
           "resource limit exceeded";
      elsif Key = "sed.error.runtime.missing_capability" then
         return
           "the sed engine does not support this construct";
      elsif Key = "sed.error.internal.unexpected" then
         return
           "internal error";
      elsif Key = "sed.hint.try_help" then
         return
           "{program}: try {option} for more information";
      elsif Key = "sed.help.usage.heading" then
         return
           "Usage:";
      elsif Key = "sed.help.usage.positional" then
         return
           "  sed [-n] script [file...]";
      elsif Key = "sed.help.usage.expressions" then
         return
           "  sed [-n] -e script [-e script]... [-f script_file]... [file...]";
      elsif Key = "sed.help.usage.script_files" then
         return
           "  sed [-n] -f script_file [-e script]... [-f script_file]... [file...]";
      elsif Key = "sed.help.summary" then
         return
           "Copy each input line to standard output, applying the editing" &
           " commands of the sed script.";
      elsif Key = "sed.help.options.heading" then
         return
           "Options:";
      elsif Key = "sed.option.quiet" then
         return
           "  -n                     suppress automatic printing of the pattern" &
           " space";
      elsif Key = "sed.option.expression" then
         return
           "  -e script              add the script text to the commands to run";
      elsif Key = "sed.option.script_file" then
         return
           "  -f script_file         add the contents of the file to the commands" &
           " to run";
      elsif Key = "sed.option.help" then
         return
           "  --help                 show this help and exit";
      elsif Key = "sed.option.version" then
         return
           "  --version              show version information and exit";
      elsif Key = "sed.option.color" then
         return
           "  --color=auto|always|never  style diagnostics only, never sed output";
      elsif Key = "sed.option.terminator" then
         return
           "  --                     end option processing";
      elsif Key = "sed.help.operands.heading" then
         return
           "Operands:";
      elsif Key = "sed.help.operands.script" then
         return
           "Without -e and -f, the first operand is the script and the rest are" &
           " input files.";
      elsif Key = "sed.help.operands.files" then
         return
           "All input operands form one logical stream: line numbers continue" &
           " across files and the address $ matches only the last line of the" &
           " whole stream.";
      elsif Key = "sed.help.operands.stdin" then
         return
           "An operand of - names standard input. With no input operand, standard" &
           " input is read.";
      elsif Key = "sed.help.exit.heading" then
         return
           "Exit status:";
      elsif Key = "sed.help.exit.success" then
         return
           "  0  success, or --help or --version";
      elsif Key = "sed.help.exit.processing" then
         return
           "  1  script, input, output or execution failure";
      elsif Key = "sed.help.exit.invocation" then
         return
           "  2  invalid invocation";
      elsif Key = "sed.help.exit.internal" then
         return
           "  3  unexpected internal failure";
      elsif Key = "sed.help.conformance.heading" then
         return
           "Conformance:";
      elsif Key = "sed.help.conformance.summary" then
         return
           "This program targets POSIX sed. GNU extensions such as -i, -E, -r," &
           " -s, -u and -z are not implemented and are rejected as unknown" &
           " options.";
      elsif Key = "sed.version.program" then
         return
           "{program} {version}";
      elsif Key = "sed.version.engine" then
         return
           "engine {name} {version}";
      elsif Key = "sed.version.license" then
         return
           "license {license}";
      else
         return "";
      end if;
   end Template;

end Sed.Localization.Defaults;
