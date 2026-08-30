with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Cut_Fields
  with SPARK_Mode => On
is
   type Parsed_Positive is record
      Valid : Boolean := False;
      Value : Natural := 0;
      Next  : Natural := 0;
   end record;

   function Invalid (First : Positive) return Parsed_Range is
   begin
      return (Valid => False, Item => (First => 1, Last => 0), Next => First);
   end Invalid;

   function Parse_Positive_At (Text : String; First : Positive) return Parsed_Positive
     with
       Pre =>
         Text /= ""
         and then First in Text'Range,
       Post =>
         (if not Parse_Positive_At'Result.Valid then
            Parse_Positive_At'Result.Value = 0
            and then Parse_Positive_At'Result.Next = First)
         and then
           (if Parse_Positive_At'Result.Valid then
              Parse_Positive_At'Result.Value > 0
              and then
                (Parse_Positive_At'Result.Next = 0
                 or else
                   (Parse_Positive_At'Result.Next in Text'Range
                    and then Parse_Positive_At'Result.Next > First)));

   function Parse_Positive_At (Text : String; First : Positive) return Parsed_Positive is
      Last : Natural := First;
   begin
      if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (First)) then
         return (Valid => False, Value => 0, Next => First);
      end if;

      while Last <= Text'Last
        and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Last))
      loop
         pragma Loop_Invariant (Last in First .. Text'Last);
         pragma Loop_Variant (Increases => Last);

         exit when Last = Text'Last;
         Last := Last + 1;
      end loop;

      declare
         Digit_Last : constant Natural :=
           (if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Last)) then Last else Last - 1);
         Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
           Posix_Tools.Text.Decimal_Parsing.Natural_Value (Text (First .. Digit_Last));
         Next : constant Natural := (if Digit_Last = Text'Last then 0 else Digit_Last + 1);
      begin
         if Parsed.Valid and then Parsed.Value > 0 then
            return (Valid => True, Value => Parsed.Value, Next => Next);
         else
            return (Valid => False, Value => 0, Next => First);
         end if;
      end;
   end Parse_Positive_At;

   function Parse_Range_Item (Text : String; First : Positive) return Parsed_Range is
      First_Value : Natural;
      Last_Value  : Natural := 0;
      Open_End    : Boolean := False;
      Cursor      : Natural;
   begin
      if Text (First) = '-' then
         if First = Text'Last then
            return Invalid (First);
         end if;

         declare
            Parsed_Last : constant Parsed_Positive := Parse_Positive_At (Text, First + 1);
         begin
            if not Parsed_Last.Valid then
               return Invalid (First);
            end if;

            First_Value := 1;
            Last_Value := Parsed_Last.Value;
            Cursor := Parsed_Last.Next;
         end;
      else
         declare
            Parsed_First : constant Parsed_Positive := Parse_Positive_At (Text, First);
         begin
            if not Parsed_First.Valid then
               return Invalid (First);
            end if;

            First_Value := Parsed_First.Value;
            Cursor := Parsed_First.Next;
         end;

         if Cursor /= 0 and then Text (Cursor) = '-' then
            if Cursor = Text'Last then
               Open_End := True;
               Cursor := 0;
            elsif Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Cursor + 1)) then
               declare
                  Parsed_Last : constant Parsed_Positive := Parse_Positive_At (Text, Cursor + 1);
               begin
                  if not Parsed_Last.Valid then
                     return Invalid (First);
                  end if;

                  Last_Value := Parsed_Last.Value;
                  Cursor := Parsed_Last.Next;
               end;
            else
               Open_End := True;
               Cursor := Cursor + 1;
            end if;
         else
            Last_Value := First_Value;
         end if;
      end if;

      if not Open_End and then Last_Value < First_Value then
         return Invalid (First);
      end if;

      return
        (Valid => True,
         Item  => (First => Positive (First_Value), Last => (if Open_End then 0 else Last_Value)),
         Next  => Cursor);
   end Parse_Range_Item;

   function Parse_List (Text : String) return Boolean is
      Index : Natural := Text'First;

      function Is_List_Separator (Ch : Character) return Boolean is
      begin
         return Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (Ch);
      end Is_List_Separator;

   begin
      if Text = "" then
         return False;
      end if;

      for Step in Text'Range loop
         pragma Unreferenced (Step);
         pragma Loop_Invariant (Index in Text'Range);

         declare
            Parsed : constant Parsed_Range := Parse_Range_Item (Text, Index);
         begin
            if not Parsed.Valid then
               return False;
            end if;

            if Parsed.Next = 0 then
               return True;
            end if;

            Index := Parsed.Next;
            if not Is_List_Separator (Text (Index)) then
               return False;
            end if;

            while Index <= Text'Last and then Is_List_Separator (Text (Index)) loop
               pragma Loop_Invariant (Index in Text'First .. Text'Last + 1);
               pragma Loop_Variant (Increases => Index);

               Index := Index + 1;
            end loop;

            if Index > Text'Last then
               return False;
            end if;
         end;
      end loop;

      return False;
   end Parse_List;
end Posix_Tools.Text.Cut_Fields;
