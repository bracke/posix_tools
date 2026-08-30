package Posix_Tools.Option_Parsing
  with SPARK_Mode => On
is
   type Parse_Status is
     (Done,
      Option,
      Operand,
      End_Of_Options,
      Unknown_Option,
      Missing_Argument);

   type Text_Source is
     (No_Text,
      Current_Argument,
      Inline_Remainder,
      Following_Argument);

   type Cursor is record
      Index  : Natural := 1;
      Offset : Natural := 2;
   end record;

   type Decision is record
      Status       : Parse_Status := Done;
      Next         : Cursor := (Index => 1, Offset => 2);
      Name         : Character := Character'Val (0);
      Source       : Text_Source := No_Text;
      Inline_First : Natural := 0;
   end record;

   function Cursor_Progresses
     (Item           : Decision;
      Position       : Cursor;
      Argument_Count : Natural) return Boolean
   is
     (Item.Next.Index >= Position.Index
      and then Item.Next.Index <= Argument_Count + 2
      and then Item.Next.Offset >= 2
      and then
        (if Item.Next.Index = Position.Index then
           Item.Next.Offset > Position.Offset
         else
           Item.Next.Offset = 2))
   with
     Pre => Argument_Count <= Natural'Last - 2;

   function Source_Is_Consistent
     (Item           : Decision;
      Position       : Cursor;
      Current        : String;
      Argument_Count : Natural) return Boolean
   is
     ((if Item.Source = Inline_Remainder then
         Item.Status = Option
         and then Item.Inline_First in Current'Range
         and then Item.Inline_First = Position.Offset + 1
       else
         Item.Inline_First = 0)
      and then
        (if Item.Source = Following_Argument then
           Item.Status = Option
           and then Position.Index < Argument_Count
           and then Item.Next.Index = Position.Index + 2
           and then Item.Next.Offset = 2)
      and then
        (if Item.Source = Current_Argument then
           Item.Status = Operand
           and then Item.Next.Index = Position.Index + 1
           and then Item.Next.Offset = 2))
   with
     Pre =>
       Current'First = 1
       and then Argument_Count <= Natural'Last - 2
       and then Position.Index <= Natural'Last - 2
       and then Position.Offset <= Natural'Last - 1;

   function Status_Is_Consistent (Item : Decision) return Boolean is
     ((if Item.Status = Done
       or else Item.Status = End_Of_Options
       or else Item.Status = Unknown_Option
       or else Item.Status = Missing_Argument
      then
        Item.Source = No_Text)
      and then
        (if Item.Status = Done
         or else Item.Status = End_Of_Options
         or else Item.Status = Operand
        then
          Item.Name = Character'Val (0)));

   function Decide_Short
     (Current           : String;
      Position          : Cursor;
      Argument_Count    : Natural;
      Accepted          : String;
      Requires_Argument : String := "") return Decision
   with
     Pre =>
       Position.Index <= Argument_Count
       and then Argument_Count <= Natural'Last - 2
       and then Position.Offset >= 2
       and then Position.Offset <= Natural'Last - 1
       and then Current'First = 1,
     Post =>
       Cursor_Progresses (Decide_Short'Result, Position, Argument_Count)
       and then Source_Is_Consistent
         (Decide_Short'Result, Position, Current, Argument_Count)
       and then Status_Is_Consistent (Decide_Short'Result);
end Posix_Tools.Option_Parsing;
