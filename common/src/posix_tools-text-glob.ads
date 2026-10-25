--  Shell-style pattern matching of names: * matches any run of characters,
--  ? any one, [...] one of a bracket expression -- with ranges, the POSIX
--  classes such as [:alpha:], and [.c.] and [=c=] for c -- and \ makes the
--  next character stand for itself, as find's -name and -path take them. A
--  '[' that nothing closes, as in "[]" and "[!]" at a pattern's end, is an
--  ordinary character.
package Posix_Tools.Text.Glob is
   function Matches (Pattern, Text : String) return Boolean;
end Posix_Tools.Text.Glob;
