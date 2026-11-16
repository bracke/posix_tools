--  Small lexical views shared by metadata validators. These functions do not
--  parse Ada; they only centralize the string/comment rules that policy
--  checkers previously reimplemented independently.
package Metadata_Checks.Ada_Lexing is
   function Code_View
     (Content                : String;
      Keep_String_Delimiters : Boolean := True) return String;
   --  Return a same-length view with comments and string contents replaced by
   --  spaces. Newlines are retained; opening and closing string quotes are
   --  retained when Keep_String_Delimiters is True.
end Metadata_Checks.Ada_Lexing;
