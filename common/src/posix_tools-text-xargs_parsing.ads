with Posix_Tools.Arguments;

package Posix_Tools.Text.Xargs_Parsing is
   type Parse_Status is
     (Valid,
      Unmatched_Single_Quote,
      Unmatched_Double_Quote,
      Unfinished_Escape);

   type Parse_Result is record
      Status : Parse_Status := Valid;
      Items  : Posix_Tools.Arguments.Vector;
   end record;

   function Parse_Input
     (Data             : String;
      Null_Delimited   : Boolean;
      Replacement_Mode : Boolean;
      Has_Eof_Marker   : Boolean;
      Eof_Marker       : String) return Parse_Result;
end Posix_Tools.Text.Xargs_Parsing;
