with Posix_Tools.Text.Matching;

package body Posix_Tools.Option_Parsing
  with SPARK_Mode => On
is
   function Advance_To_Next (Position : Cursor) return Cursor
     with
       Pre  => Position.Index <= Natural'Last - 1,
       Post =>
         Advance_To_Next'Result.Index = Position.Index + 1
         and then Advance_To_Next'Result.Offset = 2;

   function Advance_To_Next (Position : Cursor) return Cursor is
   begin
      return (Index => Position.Index + 1, Offset => 2);
   end Advance_To_Next;

   function Decide_Short
     (Current           : String;
      Position          : Cursor;
      Argument_Count    : Natural;
      Accepted          : String;
      Requires_Argument : String := "") return Decision
   is
      Ch_Index : Natural;
   begin
      if Current = "--" and then Position.Offset = 2 then
         return
           (Status       => End_Of_Options,
            Next         => Advance_To_Next (Position),
            Name         => Character'Val (0),
            Source       => No_Text,
            Inline_First => 0);
      elsif Current'Length < 2 or else Current (Current'First) /= '-' or else Current = "-" then
         return
           (Status       => Operand,
            Next         => Advance_To_Next (Position),
            Name         => Character'Val (0),
            Source       => Current_Argument,
            Inline_First => 0);
      elsif Position.Offset > Current'Length then
         return
           (Status       => Done,
            Next         => Advance_To_Next (Position),
            Name         => Character'Val (0),
            Source       => No_Text,
            Inline_First => 0);
      end if;

      Ch_Index := Position.Offset;

      declare
         Ch : constant Character := Current (Ch_Index);
      begin
         if not Posix_Tools.Text.Matching.Contains (Accepted, Ch) then
            return
              (Status       => Unknown_Option,
               Next         => Advance_To_Next (Position),
               Name         => Ch,
               Source       => No_Text,
               Inline_First => 0);
         elsif Posix_Tools.Text.Matching.Contains (Requires_Argument, Ch) then
            if Position.Offset < Current'Length then
               return
                 (Status       => Option,
                  Next         => Advance_To_Next (Position),
                  Name         => Ch,
                  Source       => Inline_Remainder,
                  Inline_First => Position.Offset + 1);
            elsif Position.Index < Argument_Count then
               return
                 (Status       => Option,
                  Next         => (Index => Position.Index + 2, Offset => 2),
                  Name         => Ch,
                  Source       => Following_Argument,
                  Inline_First => 0);
            else
               return
                 (Status       => Missing_Argument,
                  Next         => Advance_To_Next (Position),
                  Name         => Ch,
                  Source       => No_Text,
                  Inline_First => 0);
            end if;
         else
            return
              (Status       => Option,
               Next         =>
                 (if Position.Offset < Current'Length then
                    (Index => Position.Index, Offset => Position.Offset + 1)
                  else
                    Advance_To_Next (Position)),
               Name         => Ch,
               Source       => No_Text,
               Inline_First => 0);
         end if;
      end;
   end Decide_Short;
end Posix_Tools.Option_Parsing;
