with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Streams;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Base_Parsing;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Tr is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   --  One element of a set: the bytes of one character. In the C and POSIX
   --  locales every byte is a character; elsewhere characters are UTF-8, and
   --  a byte that does not start a valid sequence is a character of its own.
   package Element_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   package Element_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Natural,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   package Text_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   No_Code_Point : constant Long_Long_Integer := -1;

   --  The set operand Text as characters, for a locale with multibyte
   --  characters: ranges run over code points, and [c*n] repeats a character.
   --  Classes, equivalence classes, collating symbols and escapes are
   --  expanded by the shared byte set parser.
   function Character_Set (Text, Locale : String) return Element_Vectors.Vector;

   --  The width of the character at Index and its code point (No_Code_Point
   --  for an invalid byte). Width is 0 when Text ends inside a sequence more
   --  input might complete, unless At_End.
   procedure Decode_At
     (Text       : String;
      Index      : Positive;
      At_End     : Boolean;
      Width      : out Natural;
      Code_Point : out Long_Long_Integer);

   function Encode (Code_Point : Long_Long_Integer) return String;

   procedure Set_Success
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);

   --  Splits bytes into one-byte elements, or into characters.
   function Split (Text : String; Multibyte : Boolean) return Element_Vectors.Vector;

   function Character_Set (Text, Locale : String) return Element_Vectors.Vector is
      Output : Element_Vectors.Vector;
      I      : Positive := Text'First;

      procedure Append_Bytes (Bytes : String);

      function Code_Point_Of (Element : String) return Long_Long_Integer;

      --  Reads one element at I: an escape or one character.
      function Next_Element return String;

      --  At a '[' that may start [c*n]; False leaves I unchanged.
      function Repetition return Boolean;

      procedure Append_Bytes (Bytes : String) is
      begin
         for Element of Split (Bytes, True) loop
            Output.Append (Element);
         end loop;
      end Append_Bytes;

      function Code_Point_Of (Element : String) return Long_Long_Integer is
         Width      : Natural;
         Code_Point : Long_Long_Integer;
      begin
         if Element = "" then
            return No_Code_Point;
         end if;
         Decode_At (Element, Element'First, True, Width, Code_Point);
         return (if Width = Element'Length then Code_Point else No_Code_Point);
      end Code_Point_Of;

      function Next_Element return String is
         First      : constant Positive := I;
         Width      : Natural;
         Code_Point : Long_Long_Integer;
      begin
         if Text (I) = '\' and then I < Text'Last then
            I := I + 1;
            if Text (I) in '0' .. '7' then
               while I < Text'Last and then I - First < 3 and then Text (I + 1) in '0' .. '7' loop
                  I := I + 1;
               end loop;
            end if;
            I := I + 1;
            return Posix_Tools.Commands.Text_Helpers.Translation_Set_From_Spec (Text (First .. I - 1), Locale);
         end if;
         Decode_At (Text, I, True, Width, Code_Point);
         I := I + Width;
         return Text (First .. I - 1);
      end Next_Element;

      function Repetition return Boolean is
         Start : constant Positive := I;
         Count : Natural := 0;
         Close : Natural := 0;
      begin
         I := I + 1;
         declare
            Repeated : constant String := Next_Element;
         begin
            if I <= Text'Last and then Text (I) = '*' then
               for J in I + 1 .. Text'Last loop
                  if Text (J) = ']' then
                     Close := J;
                     exit;
                  elsif Text (J) not in '0' .. '9' then
                     exit;
                  end if;
               end loop;
            end if;
            if Close = 0 then
               I := Start;
               return False;
            end if;

            --  [c*] fills; a count with a leading zero is octal.
            if Close = I + 1 then
               Count := 256;
            else
               declare
                  Parsed : constant Posix_Tools.Text.Base_Parsing.Parsed_Natural :=
                    Posix_Tools.Text.Base_Parsing.Natural_Value
                      (Text (I + 1 .. Close - 1), (if Text (I + 1) = '0' then 8 else 10));
               begin
                  if not Parsed.Valid then
                     I := Start;
                     return False;
                  end if;
                  Count := Parsed.Value;
               end;
            end if;
            for J in 1 .. Count loop
               Output.Append (Repeated);
            end loop;
            I := Close + 1;
            return True;
         end;
      end Repetition;
   begin
      while I <= Text'Last loop
         if Text (I) = '[' and then I < Text'Last and then Text (I + 1) in ':' | '=' | '.' then
            declare
               Marker : constant Character := Text (I + 1);
               Close  : Natural := 0;
            begin
               for J in I + 3 .. Text'Last - 1 loop
                  if Text (J) = Marker and then Text (J + 1) = ']' then
                     Close := J + 1;
                     exit;
                  end if;
               end loop;
               if Close = 0 then
                  Output.Append (Next_Element);
               else
                  Append_Bytes
                    (Posix_Tools.Commands.Text_Helpers.Translation_Set_From_Spec (Text (I .. Close), Locale));
                  I := Close + 1;
               end if;
            end;
         elsif Text (I) = '[' and then I + 2 <= Text'Last and then Repetition then
            null;
         else
            declare
               Low : constant String := Next_Element;
            begin
               if I < Text'Last and then Text (I) = '-' then
                  I := I + 1;
                  declare
                     High      : constant String := Next_Element;
                     Low_Code  : constant Long_Long_Integer := Code_Point_Of (Low);
                     High_Code : constant Long_Long_Integer := Code_Point_Of (High);
                  begin
                     if Low_Code /= No_Code_Point and then High_Code /= No_Code_Point and then Low_Code <= High_Code
                     then
                        for Code in Low_Code .. High_Code loop
                           if Code not in 16#D800# .. 16#DFFF# then
                              Output.Append (Encode (Code));
                           end if;
                        end loop;
                     else
                        Append_Bytes (Low);
                        Output.Append ("-");
                        Append_Bytes (High);
                     end if;
                  end;
               else
                  Append_Bytes (Low);
               end if;
            end;
         end if;
      end loop;
      return Output;
   end Character_Set;

   procedure Decode_At
     (Text       : String;
      Index      : Positive;
      At_End     : Boolean;
      Width      : out Natural;
      Code_Point : out Long_Long_Integer)
   is
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      Status  : Posix_Tools.Text.UTF_8.Decode_Status;
   begin
      for I in Index .. Text'Last loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Text (I)), Status, Code_Point);
         if Status = Posix_Tools.Text.UTF_8.Complete then
            Width := I - Index + 1;
            return;
         elsif Status = Posix_Tools.Text.UTF_8.Invalid then
            Width := 1;
            Code_Point := No_Code_Point;
            return;
         end if;
      end loop;
      Width := (if At_End then 1 else 0);
      Code_Point := No_Code_Point;
   end Decode_At;

   function Encode (Code_Point : Long_Long_Integer) return String is
      function Byte (Value : Long_Long_Integer) return Character is (Character'Val (Natural (Value)));
   begin
      if Code_Point < 16#80# then
         return [Byte (Code_Point)];
      elsif Code_Point < 16#800# then
         return [Byte (16#C0# + Code_Point / 64), Byte (16#80# + Code_Point mod 64)];
      elsif Code_Point < 16#1_0000# then
         return
           [Byte (16#E0# + Code_Point / 4096),
            Byte (16#80# + (Code_Point / 64) mod 64),
            Byte (16#80# + Code_Point mod 64)];
      else
         return
           [Byte (16#F0# + Code_Point / 262_144),
            Byte (16#80# + (Code_Point / 4096) mod 64),
            Byte (16#80# + (Code_Point / 64) mod 64),
            Byte (16#80# + Code_Point mod 64)];
      end if;
   end Encode;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Delete_Mode : Boolean := False;
      Complement  : Boolean := False;
      Squeeze     : Boolean := False;
      First       : Positive := 1;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (Context.Argument (First)'First) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;

         for Ch of Context.Argument (First) (Context.Argument (First)'First + 1 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'c' | 'C' => Complement := True;
               when 'd' => Delete_Mode := True;
               when 's' => Squeeze := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unknown_Option, "-" & Ch);
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if (Delete_Mode and then Squeeze and then Context.Argument_Count /= First + 1)
        or else (Delete_Mode and then (not Squeeze) and then Context.Argument_Count /= First)
        or else ((not Delete_Mode) and then Squeeze and then Context.Argument_Count not in First | First + 1)
        or else ((not Delete_Mode) and then (not Squeeze) and then Context.Argument_Count /= First + 1)
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      declare
         Locale    : constant String :=
           Context.Category_Locale (Posix_Tools.Commands.Contexts.Character_Classification);
         Multibyte : constant Boolean := Posix_Tools.Commands.Text_Helpers.Is_Multibyte_Locale (Locale);
         Has_Set2  : constant Boolean := Context.Argument_Count = First + 1;

         function Parse_Set (Operand : String) return Element_Vectors.Vector is
           (if Multibyte then Character_Set (Operand, Locale)
            else Split (Posix_Tools.Commands.Text_Helpers.Translation_Set_From_Spec (Operand, Locale), False));

         Set1 : constant Element_Vectors.Vector := Parse_Set (Context.Argument (First));
         Set2 : constant Element_Vectors.Vector :=
           (if Has_Set2 then Parse_Set (Context.Argument (First + 1)) else Element_Vectors.Empty_Vector);

         --  Where each character of a set is; a character listed twice in
         --  SET1 maps by its last occurrence.
         Positions1 : Element_Maps.Map;
         Members2   : Element_Maps.Map;
         --  The single-byte complement of SET1 in collation order.
         Complement_Order : Unbounded_String;
         --  Translations already worked out; "" when the character is deleted.
         Translated : Text_Maps.Map;

         Pending       : Unbounded_String;
         Previous      : Unbounded_String;
         Have_Previous : Boolean := False;
         Ok            : Boolean;

         --  -c: a character's position in the complement of SET1. Bytes, and
         --  ASCII characters, come in the locale's collation order; other
         --  characters follow them in code point order.
         function Complement_Position (Element : String; Code_Point : Long_Long_Integer) return Natural;

         function In_Effective_Set1 (Element : String) return Boolean is
           (Positions1.Contains (Element) /= Complement);

         --  POSIX tr -s: squeeze repeats of characters "in the last operand",
         --  SET2 when given, else SET1 (complemented under -c).
         function In_Squeeze_Set (Element : String) return Boolean is
           (if Has_Set2 then Members2.Contains (Element) else In_Effective_Set1 (Element));

         procedure Process (Data : String; At_End : Boolean);

         procedure Process_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         function Translate (Element : String; Code_Point : Long_Long_Integer) return String;

         function Complement_Position (Element : String; Code_Point : Long_Long_Integer) return Natural is
            Below : Natural := 0;
            Seen  : Element_Maps.Map;
         begin
            if not Multibyte or else Code_Point in 0 .. 16#7F# then
               for I in 1 .. Length (Complement_Order) loop
                  if Element (Element'First) = Ada.Strings.Unbounded.Element (Complement_Order, I) then
                     return I;
                  end if;
               end loop;
               return 0;
            elsif Code_Point = No_Code_Point then
               return Natural'Last;
            end if;

            for Member of Set1 loop
               declare
                  Width : Natural;
                  Code  : Long_Long_Integer;
               begin
                  Decode_At (Member, Member'First, True, Width, Code);
                  if Code in 16#80# .. Code_Point - 1 and then not Seen.Contains (Member) then
                     Seen.Insert (Member, 0);
                     Below := Below + 1;
                  end if;
               end;
            end loop;
            return 256 + Natural (Code_Point) - Below;
         end Complement_Position;

         procedure Process (Data : String; At_End : Boolean) is
            Output : Unbounded_String;
            I      : Positive := Data'First;
         begin
            while I <= Data'Last loop
               declare
                  Width      : Natural := 1;
                  Code_Point : Long_Long_Integer := No_Code_Point;
               begin
                  if Multibyte then
                     Decode_At (Data, I, At_End, Width, Code_Point);
                     if Width = 0 then
                        Pending := To_Unbounded_String (Data (I .. Data'Last));
                        exit;
                     end if;
                  end if;

                  declare
                     Element : constant String := Data (I .. I + Width - 1);
                     Out_Text : constant String := Translate (Element, Code_Point);
                  begin
                     if Out_Text /= ""
                       and then not (Squeeze
                                     and then Have_Previous
                                     and then Out_Text = To_String (Previous)
                                     and then In_Squeeze_Set (Out_Text))
                     then
                        Append (Output, Out_Text);
                        Previous := To_Unbounded_String (Out_Text);
                        Have_Previous := True;
                     end if;
                  end;
                  I := I + Width;
               end;
            end loop;
            Context.Put (To_String (Output));
         end Process;

         procedure Process_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Context);
            Data : String (1 .. Length (Pending) + Natural (Last - Buffer'First + 1));
         begin
            Data (1 .. Length (Pending)) := To_String (Pending);
            for I in Buffer'First .. Last loop
               Data (Length (Pending) + 1 + Natural (I - Buffer'First)) := Character'Val (Natural (Buffer (I)));
            end loop;
            Pending := Null_Unbounded_String;
            Process (Data, At_End => False);
         end Process_Chunk;

         function Translate (Element : String; Code_Point : Long_Long_Integer) return String is
         begin
            if Translated.Contains (Element) then
               return Translated.Element (Element);
            end if;

            declare
               Match : constant Boolean := In_Effective_Set1 (Element);
               Index : constant Natural :=
                 (if not Match or else Delete_Mode or else not Has_Set2 then 0
                  elsif Complement then Complement_Position (Element, Code_Point)
                  else Positions1.Element (Element));
               Result_Text : constant String :=
                 (if Delete_Mode and then Match then ""
                  elsif Match and then Has_Set2 and then not Set2.Is_Empty and then not Delete_Mode
                  then Set2 (Natural'Max (1, Natural'Min (Index, Natural (Set2.Length))))
                  else Element);
            begin
               Translated.Insert (Element, Result_Text);
               return Result_Text;
            end;
         end Translate;

         procedure Each_Chunk is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk (Process_Chunk);
      begin
         for I in 1 .. Natural (Set1.Length) loop
            Positions1.Include (Set1 (I), I);
         end loop;
         for I in 1 .. Natural (Set2.Length) loop
            Members2.Include (Set2 (I), I);
         end loop;
         if Complement then
            declare
               Bytes : Unbounded_String;
            begin
               for Element of Set1 loop
                  if not Multibyte or else Character'Pos (Element (Element'First)) < 16#80# then
                     Append (Bytes, Element);
                  end if;
               end loop;
               Complement_Order :=
                 To_Unbounded_String
                   (Posix_Tools.Commands.Text_Helpers.Locale_Collation_Order (Locale, To_String (Bytes)));
            end;
         end if;

         Each_Chunk (Context, "-", Ok);
         if Ok and then Length (Pending) > 0 then
            Process (To_String (Pending), At_End => True);
         end if;
         Set_Success (Context, Result);
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         end if;
      end;
   end Run;

   procedure Set_Success
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Set_Success;

   function Split (Text : String; Multibyte : Boolean) return Element_Vectors.Vector is
      Output     : Element_Vectors.Vector;
      I          : Positive := Text'First;
      Width      : Natural := 1;
      Code_Point : Long_Long_Integer;
   begin
      while I <= Text'Last loop
         if Multibyte then
            Decode_At (Text, I, True, Width, Code_Point);
         end if;
         Output.Append (Text (I .. I + Width - 1));
         I := I + Width;
      end loop;
      return Output;
   end Split;
end Posix_Tools.Commands.Tr;
