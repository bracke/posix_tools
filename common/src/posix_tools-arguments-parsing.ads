with Ada.Strings.Unbounded;

package Posix_Tools.Arguments.Parsing is
   type Parse_Status is
     (Done,
      Option,
      Operand,
      End_Of_Options,
      Unknown_Option,
      Missing_Argument);

   type Cursor is record
      Index  : Positive := 1;
      Offset : Positive := 2;
   end record;

   type Result is record
      Status : Parse_Status := Done;
      Next   : Cursor := (Index => 1, Offset => 2);
      Name   : Character := Character'Val (0);
      Text   : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Parse_Short
     (Arguments         : Posix_Tools.Arguments.Vector;
      Position          : Cursor;
      Accepted          : String;
      Requires_Argument : String := "") return Result;
end Posix_Tools.Arguments.Parsing;
