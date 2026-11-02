with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Commands.Text_Helpers.Tr_Sets;

package body Posix_Tools.Commands.Grep.Patterns is
   use Ada.Strings.Unbounded;

   --  Append Text to Result as members of a bracket expression.
   procedure Append_Class_Literal (Result : in out Unbounded_String; Text : String);

   --  The index of the "]" that closes the bracket expression starting at
   --  First, or zero when it is not closed.
   function Basic_Bracket_End (Pattern : String; First : Natural) return Natural;

   --  The index of the "\}" that closes an interval whose bounds start at
   --  First, or zero when it is not closed.
   function Basic_Interval_End (Pattern : String; First : Natural) return Natural;

   --  The index of the Marker of the Marker-"]" pair that closes a bracket
   --  element starting at First, or zero.
   function Bracket_Element_End
     (Pattern : String;
      First   : Natural;
      Marker  : Character) return Natural;

   --  The bracket expression Pattern (First .. Last) with its ranges,
   --  equivalence classes, and collating symbols resolved in Locale.
   function Translate_Basic_Bracket
     (Pattern : String;
      First   : Natural;
      Last    : Natural;
      Locale  : String) return String;

   procedure Append_Class_Literal (Result : in out Unbounded_String; Text : String) is
   begin
      for Ch of Text loop
         if Ch in '\' | ']' | '^' | '-' then
            Append (Result, '\');
         end if;
         Append (Result, Ch);
      end loop;
   end Append_Class_Literal;

   procedure Append_Pattern_File (List : in out Text_Vectors.Vector; Data : String) is
   begin
      if Data = "" then
         return;
      elsif Data (Data'Last) = ASCII.LF then
         Append_Pattern_List (List, Data (Data'First .. Data'Last - 1));
      else
         Append_Pattern_List (List, Data);
      end if;
   end Append_Pattern_File;

   procedure Append_Pattern_List (List : in out Text_Vectors.Vector; Text : String) is
      First : Positive := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = ASCII.LF then
            List.Append (Text (First .. I - 1));
            First := I + 1;
         end if;
      end loop;
      List.Append (Text (First .. Text'Last));
   end Append_Pattern_List;

   function Basic_Bracket_End (Pattern : String; First : Natural) return Natural is
      I : Natural := First + 1;
   begin
      if I <= Pattern'Last and then Pattern (I) in '^' | '!' then
         I := I + 1;
      end if;
      if I <= Pattern'Last and then Pattern (I) = ']' then
         I := I + 1;
      end if;

      while I <= Pattern'Last loop
         if I + 1 <= Pattern'Last
           and then Pattern (I) = '['
           and then Pattern (I + 1) in ':' | '=' | '.'
         then
            declare
               Closing : constant Natural := Bracket_Element_End (Pattern, I + 2, Pattern (I + 1));
            begin
               if Closing /= 0 then
                  I := Closing + 2;
               else
                  I := I + 1;
               end if;
            end;
         elsif Pattern (I) = ']' then
            return I;
         else
            I := I + 1;
         end if;
      end loop;

      return 0;
   end Basic_Bracket_End;

   function Basic_Interval_End (Pattern : String; First : Natural) return Natural is
      I : Natural := First;
   begin
      while I <= Pattern'Last loop
         if Pattern (I) = '\'
           and then I < Pattern'Last
           and then Pattern (I + 1) = '}'
         then
            return I;
         end if;
         I := I + 1;
      end loop;

      return 0;
   end Basic_Interval_End;

   function Basic_To_Extended (Pattern : String; Locale : String) return String is
      Result : Unbounded_String;
      I      : Natural := Pattern'First;
   begin
      while I <= Pattern'Last loop
         case Pattern (I) is
            when '[' =>
               declare
                  Closing : constant Natural := Basic_Bracket_End (Pattern, I);
               begin
                  if Closing = 0 then
                     Append (Result, Pattern (I));
                  else
                     Append (Result, Translate_Basic_Bracket (Pattern, I, Closing, Locale));
                     I := Closing;
                  end if;
               end;
            when '\' =>
               if I = Pattern'Last then
                  Append (Result, '\');
               else
                  declare
                     Next : constant Character := Pattern (I + 1);
                  begin
                     case Next is
                        when '(' | ')' =>
                           Append (Result, Next);
                        when '{' =>
                           declare
                              Closing : constant Natural := Basic_Interval_End (Pattern, I + 2);
                           begin
                              if Closing = 0 then
                                 Append (Result, "\{");
                              else
                                 Append (Result, '{');
                                 if I + 2 <= Closing - 1 then
                                    Append (Result, Pattern (I + 2 .. Closing - 1));
                                 end if;
                                 Append (Result, '}');
                                 I := Closing;
                              end if;
                           end;
                        when '+' | '?' | '|' =>
                           Append (Result, Next);
                        when others =>
                           Append (Result, '\');
                           Append (Result, Next);
                     end case;
                     I := I + 1;
                  end;
               end if;
            when '+' | '?' | '|' | '(' | ')' | '{' | '}' =>
               Append (Result, '\');
               Append (Result, Pattern (I));
            when others =>
               Append (Result, Pattern (I));
         end case;
         I := I + 1;
      end loop;

      return To_String (Result);
   end Basic_To_Extended;

   function Bracket_Element_End
     (Pattern : String;
      First   : Natural;
      Marker  : Character) return Natural
   is
      I : Natural := First;
   begin
      while I < Pattern'Last loop
         if Pattern (I) = Marker and then Pattern (I + 1) = ']' then
            return I;
         end if;
         I := I + 1;
      end loop;

      return 0;
   end Bracket_Element_End;

   function Translate_Basic_Bracket
     (Pattern : String;
      First   : Natural;
      Last    : Natural;
      Locale  : String) return String
   is
      Class_Text   : Unbounded_String;
      Alternatives : Text_Vectors.Vector;
      I            : Natural := First + 1;
      Negated      : Boolean := False;
      Changed      : Boolean := False;

      --  Append the characters from Low to High in the collation order.
      procedure Append_Locale_Range (Low, High : Character);

      procedure Append_Locale_Range (Low, High : Character) is
         Order : constant String :=
           Posix_Tools.Commands.Text_Helpers.Collation.Locale_Collation_Order (Locale, "");
         Low_Pos  : Natural := 0;
         High_Pos : Natural := 0;
      begin
         for J in Order'Range loop
            if Order (J) = Low and then Low_Pos = 0 then
               Low_Pos := J;
            end if;
            if Order (J) = High and then High_Pos = 0 then
               High_Pos := J;
            end if;
         end loop;

         if Low_Pos = 0 or else High_Pos = 0 or else Low_Pos > High_Pos then
            Append_Class_Literal (Class_Text, [1 => Low]);
            Append_Class_Literal (Class_Text, "-");
            Append_Class_Literal (Class_Text, [1 => High]);
         else
            Append_Class_Literal (Class_Text, Order (Low_Pos .. High_Pos));
         end if;
      end Append_Locale_Range;
   begin
      if I <= Last - 1 and then Pattern (I) in '^' | '!' then
         Negated := True;
         Append (Class_Text, Pattern (I));
         I := I + 1;
      end if;

      while I <= Last - 1 loop
         if I + 1 <= Last - 1
           and then Pattern (I) = '['
           and then Pattern (I + 1) in ':' | '=' | '.'
         then
            declare
               Marker  : constant Character := Pattern (I + 1);
               Closing : constant Natural := Bracket_Element_End (Pattern, I + 2, Marker);
            begin
               if Closing = 0 or else Closing + 1 > Last - 1 then
                  Append (Class_Text, Pattern (I));
                  I := I + 1;
               elsif Marker = ':' then
                  Append (Class_Text, Pattern (I .. Closing + 1));
                  I := Closing + 2;
               elsif Marker = '=' then
                  Append_Class_Literal
                    (Class_Text,
                     Posix_Tools.Commands.Text_Helpers.Tr_Sets.Byte_Set (Pattern (I .. Closing + 1), Locale));
                  Changed := True;
                  I := Closing + 2;
               else
                  declare
                     Symbol : constant String :=
                       Posix_Tools.Commands.Text_Helpers.Tr_Sets.Byte_Set (Pattern (I .. Closing + 1), Locale);
                  begin
                     if Symbol'Length = 1 then
                        Append_Class_Literal (Class_Text, Symbol);
                     else
                        Alternatives.Append (Symbol);
                     end if;
                     Changed := True;
                     I := Closing + 2;
                  end;
               end if;
            end;
         elsif I + 2 <= Last - 1 and then Pattern (I + 1) = '-' then
            Append_Locale_Range (Pattern (I), Pattern (I + 2));
            Changed := True;
            I := I + 3;
         else
            Append (Class_Text, Pattern (I));
            I := I + 1;
         end if;
      end loop;

      if not Changed then
         return Pattern (First .. Last);
      elsif Alternatives.Is_Empty then
         return "[" & To_String (Class_Text) & "]";
      elsif Negated then
         return Pattern (First .. Last);
      else
         declare
            Output : Unbounded_String;
         begin
            Append (Output, "(?:");
            if Length (Class_Text) > 0 then
               Append (Output, "[" & To_String (Class_Text) & "]");
            end if;
            for J in 1 .. Natural (Alternatives.Length) loop
               if Length (Class_Text) > 0 or else J > 1 then
                  Append (Output, "|");
               end if;
               Append (Output, Basic_To_Extended (Alternatives.Element (J), Locale));
            end loop;
            Append (Output, ")");
            return To_String (Output);
         end;
      end if;
   end Translate_Basic_Bracket;
end Posix_Tools.Commands.Grep.Patterns;
