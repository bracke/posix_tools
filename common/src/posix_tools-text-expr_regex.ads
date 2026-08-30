with Ada.Strings.Unbounded;

package Posix_Tools.Text.Expr_Regex is
   type Match_Status is (Match_Valid, Match_Invalid_Expression);

   type Match_Result is record
      Status : Match_Status := Match_Valid;
      Value  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Match (Text : String; Pattern : String) return Match_Result;
end Posix_Tools.Text.Expr_Regex;
