with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Streams;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Commands.Text_Helpers.Tr_Sets;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Tr is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;

   package Sets renames Posix_Tools.Commands.Text_Helpers.Tr_Sets;
   package Element_Vectors renames Sets.Element_Vectors;

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
      declare
         --  Translating takes string1 and string2, -d string1 and -d -s
         --  both; -s alone takes string1 and perhaps string2.
         Least    : constant Positive := (if Delete_Mode = Squeeze then 2 else 1);
         Most     : constant Positive := (if Delete_Mode and then not Squeeze then 1 else 2);
         Operands : constant Natural := Context.Argument_Count - First + 1;
      begin
         if Operands < Least then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
            return;
         elsif Operands > Most then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (First + Most));
            return;
         end if;
      end;

      declare
         Locale    : constant String :=
           Context.Category_Locale (Posix_Tools.Commands.Contexts.Character_Classification);
         Multibyte : constant Boolean := Posix_Tools.Commands.Text_Helpers.Collation.Is_Multibyte_Locale (Locale);
         Has_Set2  : constant Boolean := Context.Argument_Count = First + 1;

         Set1 : constant Element_Vectors.Vector := Sets.Operand_Set (Context.Argument (First), Locale, Multibyte);
         Set2 : constant Element_Vectors.Vector :=
           (if Has_Set2 then Sets.Operand_Set (Context.Argument (First + 1), Locale, Multibyte)
            else Element_Vectors.Empty_Vector);

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
            elsif Code_Point = Sets.No_Code_Point then
               return Natural'Last;
            end if;

            for Member of Set1 loop
               declare
                  Width : Natural;
                  Code  : Long_Long_Integer;
               begin
                  Sets.Decode_At (Member, Member'First, True, Width, Code);
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
                  Code_Point : Long_Long_Integer := Sets.No_Code_Point;
               begin
                  if Multibyte then
                     Sets.Decode_At (Data, I, At_End, Width, Code_Point);
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

         procedure Each_Chunk is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk (Process_Chunk);
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
                   (Posix_Tools.Commands.Text_Helpers.Collation.Locale_Collation_Order (Locale, To_String (Bytes)));
            end;
         end if;

         Each_Chunk (Context, "-", Ok);
         if Ok and then Length (Pending) > 0 then
            Process (To_String (Pending), At_End => True);
         end if;
         Posix_Tools.Commands.Helpers.Finish (Context, Result);
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         end if;
      end;
   end Run;

end Posix_Tools.Commands.Tr;
