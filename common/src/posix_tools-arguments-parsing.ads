with Ada.Containers;
with Ada.Strings.Unbounded;

package Posix_Tools.Arguments.Parsing
  with SPARK_Mode => Off
is
   use type Ada.Containers.Count_Type;

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
      Requires_Argument : String := "") return Result
   with
     Pre =>
       Arguments.Length <= Ada.Containers.Count_Type (Natural'Last - 1)
       and then Position.Index <= Natural (Arguments.Length) + 1
       and then Position.Offset >= 2,
     Post =>
       Parse_Short'Result.Next.Index <= Natural (Arguments.Length) + 2
       and then Parse_Short'Result.Next.Offset >= 2
       and then
         (if Parse_Short'Result.Status in Done | Operand | End_Of_Options then
            Parse_Short'Result.Name = Character'Val (0))
       and then
         (if Parse_Short'Result.Status = Option then
            (for some I in Accepted'Range =>
               Accepted (I) = Parse_Short'Result.Name))
       and then
         (if Parse_Short'Result.Status = Missing_Argument then
            (for some I in Requires_Argument'Range =>
               Requires_Argument (I) = Parse_Short'Result.Name))
       and then
         (if Parse_Short'Result.Status = Unknown_Option then
            Parse_Short'Result.Name /= Character'Val (0)
            and then
              (for all I in Accepted'Range =>
                 Accepted (I) /= Parse_Short'Result.Name))
       and then
         (if Parse_Short'Result.Status in Done | End_Of_Options | Unknown_Option | Missing_Argument then
            Ada.Strings.Unbounded.Length (Parse_Short'Result.Text) = 0);
end Posix_Tools.Arguments.Parsing;
