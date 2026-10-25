--  Shell-style pattern matching of names: * matches any run of characters,
--  ? any one, [...] one of a class, and \ makes the next character stand
--  for itself, as find's -name and -path take them.
package Posix_Tools.Text.Glob is
   function Matches (Pattern, Text : String) return Boolean;
end Posix_Tools.Text.Glob;
