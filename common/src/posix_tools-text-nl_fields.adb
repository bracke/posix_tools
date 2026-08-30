with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.NL_Fields
  with SPARK_Mode => On
is
   LF : constant Character := Character'Val (10);

   function Matches_Repeated_Delimiter
     (Line : String;
      First_Delimiter : Character;
      Second_Delimiter : Character;
      Count : Positive) return Boolean;

   function Is_Empty_Line (Line : String) return Boolean is
   begin
      return Line = "" or else Line = "" & LF;
   end Is_Empty_Line;

   function Logical_Section_For
     (Line : String;
      First_Delimiter : Character;
      Second_Delimiter : Character) return Logical_Section
   is
   begin
      if Matches_Repeated_Delimiter (Line, First_Delimiter, Second_Delimiter, 3) then
         return Header_Section;
      elsif Matches_Repeated_Delimiter (Line, First_Delimiter, Second_Delimiter, 2) then
         return Body_Section;
      elsif Matches_Repeated_Delimiter (Line, First_Delimiter, Second_Delimiter, 1) then
         return Footer_Section;
      else
         return No_Section;
      end if;
   end Logical_Section_For;

   function Matches_Repeated_Delimiter
     (Line : String;
      First_Delimiter : Character;
      Second_Delimiter : Character;
      Count : Positive) return Boolean
   is
   begin
      case Count is
         when 1 =>
            return
              Line = "" & First_Delimiter & Second_Delimiter
              or else Line = "" & First_Delimiter & Second_Delimiter & LF;
         when 2 =>
            return
              Line =
                "" & First_Delimiter & Second_Delimiter
                & First_Delimiter & Second_Delimiter
              or else
                Line =
                  "" & First_Delimiter & Second_Delimiter
                  & First_Delimiter & Second_Delimiter & LF;
         when 3 =>
            return
              Line =
                "" & First_Delimiter & Second_Delimiter
                & First_Delimiter & Second_Delimiter
                & First_Delimiter & Second_Delimiter
              or else
                Line =
                  "" & First_Delimiter & Second_Delimiter
                  & First_Delimiter & Second_Delimiter
                  & First_Delimiter & Second_Delimiter & LF;
         when others =>
            return False;
      end case;
   end Matches_Repeated_Delimiter;

   function Mode_For (Text : String) return Number_Mode is
   begin
      if Text = "a" then
         return All_Lines;
      elsif Text = "t" then
         return Nonempty_Lines;
      elsif Text = "n" then
         return No_Lines;
      else
         return Unknown_Number_Mode;
      end if;
   end Mode_For;

   function Positive_Long_Value (Text : String) return Parsed_Long_Long is
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
        Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Text);
   begin
      if Text /= ""
        and then Text (Text'First) not in '+' | '-'
        and then Parsed.Valid
        and then Parsed.Value > 0
      then
         return (Valid => True, Value => Parsed.Value);
      else
         return (Valid => False, Value => 0);
      end if;
   end Positive_Long_Value;
end Posix_Tools.Text.NL_Fields;
