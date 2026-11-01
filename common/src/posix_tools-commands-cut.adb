with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Cut_Fields;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Cut is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.Cut_Fields.Range_Item;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   LF : constant Character := Character'Val (10);

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;
   package Range_Vectors is new Ada.Containers.Vectors
     (Positive, Posix_Tools.Text.Cut_Fields.Range_Item);

   --  The number of bytes of the UTF-8 character starting at Index; an
   --  invalid or truncated sequence counts as a one-byte character.
   function Character_Width (Text : String; Index : Positive) return Positive;

   function Parse_List (Text : String; Ranges : in out Range_Vectors.Vector) return Boolean;
   function Selected (Ranges : Range_Vectors.Vector; Position : Positive) return Boolean;

   --  -b with -n: the selected bytes after POSIX moves each range's low end
   --  back to the start of its character and its high end back before a
   --  character it would split; a range left empty is dropped.
   function Whole_Character_Bytes (Ranges : Range_Vectors.Vector; Line : String) return String;

   --  -c: the selected characters.
   function Selected_Characters (Ranges : Range_Vectors.Vector; Line : String) return String;

   function Character_Width (Text : String; Index : Positive) return Positive is
      Decoder    : Posix_Tools.Text.UTF_8.Decoder;
      Status     : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer;
   begin
      for I in Index .. Text'Last loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Text (I)), Status, Code_Point);
         if Status = Posix_Tools.Text.UTF_8.Complete then
            return I - Index + 1;
         elsif Status = Posix_Tools.Text.UTF_8.Invalid then
            return 1;
         end if;
      end loop;
      return 1;
   end Character_Width;

   function Parse_List (Text : String; Ranges : in out Range_Vectors.Vector) return Boolean is
      Index : Positive := Text'First;

      function Is_List_Separator (Ch : Character) return Boolean;

      function Is_List_Separator (Ch : Character) return Boolean is
      begin
         return Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (Ch);
      end Is_List_Separator;

   begin
      Ranges.Clear;
      if not Posix_Tools.Text.Cut_Fields.Parse_List (Text) then
         return False;
      end if;

      while Index <= Text'Last loop
         declare
            Parsed : constant Posix_Tools.Text.Cut_Fields.Parsed_Range :=
              Posix_Tools.Text.Cut_Fields.Parse_Range_Item (Text, Index);
         begin
            if not Parsed.Valid then
               return False;
            end if;
            Ranges.Append (Parsed.Item);
            exit when Parsed.Next = 0;
            Index := Parsed.Next;
            if not Is_List_Separator (Text (Index)) then
               return False;
            end if;
            while Index <= Text'Last and then Is_List_Separator (Text (Index)) loop
               Index := Index + 1;
            end loop;
            if Index > Text'Last then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Parse_List;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Mode       : Character := Character'Val (0);
      Ranges     : Range_Vectors.Vector;
      Delimiter  : Character := Character'Val (9);
      Has_Delimiter : Boolean := False;
      Suppress   : Boolean := False;
      No_Split   : Boolean := False;
      First_File : Positive;
      Valid      : Boolean;
      All_Ok     : Boolean := True;
      Characters : constant Boolean :=
        Posix_Tools.Commands.Text_Helpers.Is_Multibyte_Locale
          (Context.Category_Locale (Posix_Tools.Commands.Contexts.Character_Classification));

      procedure Cut_File (Name : String; Ok : out Boolean);
      procedure Emit_Line (Line : String);
      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Cut_File (Name : String; Ok : out Boolean) is
         Data  : Unbounded_String;
         Lines : String_Vectors.Vector;
      begin
         Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Name, Data, Ok);
         if not Ok then
            return;
         end if;
         Lines := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Data));
         for Line of Lines loop
            Emit_Line (Line);
            if Context.Output_Failed then
               Ok := False;
               return;
            end if;
         end loop;
      end Cut_File;

      procedure Emit_Line (Line : String) is
         Clean  : constant String :=
           (if Line'Length > 0 and then Line (Line'Last) = LF
            then Line (Line'First .. Line'Last - 1)
            else Line);
         Output : Unbounded_String;
         Field  : Positive := 1;
         Start  : Positive := Clean'First;
         Seen_Delimiter : Boolean := False;
      begin
         if Mode = 'c' and then Characters then
            Context.Put_Line (Selected_Characters (Ranges, Clean));
         elsif Mode = 'b' and then No_Split and then Characters then
            Context.Put_Line (Whole_Character_Bytes (Ranges, Clean));
         elsif Mode = 'b' or else Mode = 'c' then
            for I in Clean'Range loop
               if Selected (Ranges, I - Clean'First + 1) then
                  Append (Output, Clean (I));
               end if;
            end loop;
            Context.Put_Line (To_String (Output));
         else
            for I in Clean'Range loop
               if Clean (I) = Delimiter then
                  Seen_Delimiter := True;
                  if Selected (Ranges, Field) then
                     if Length (Output) > 0 then
                        Append (Output, Delimiter);
                     end if;
                     Append (Output, Clean (Start .. I - 1));
                  end if;
                  Field := Field + 1;
                  Start := I + 1;
               end if;
            end loop;
            if Selected (Ranges, Field) then
               if Length (Output) > 0 then
                  Append (Output, Delimiter);
               end if;
               if Start <= Clean'Last then
                  Append (Output, Clean (Start .. Clean'Last));
               end if;
            end if;
            if Seen_Delimiter or else not Suppress then
               Context.Put_Line ((if Seen_Delimiter then To_String (Output) else Clean));
            end if;
         end if;
      end Emit_Line;

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
      begin
         Valid := False;
         case Name is
            when 's' =>
               Suppress := True;
            when 'n' =>
               No_Split := True;
            when 'd' =>
               if Value'Length /= 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  return;
               end if;
               Delimiter := Value (Value'First);
               Has_Delimiter := True;
            when others =>
               --  -b, -c or -f, with its list.
               if Mode /= Character'Val (0) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Multiple_List_Options);
                  return;
               elsif Value = "" then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, "-" & Name);
                  return;
               elsif not Parse_List (Value, Ranges) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  return;
               end if;
               Mode := Name;
         end case;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "bcdfns", "bcdf", First_File, Valid);
      if not Valid then
         return;
      end if;

      if Mode = Character'Val (0) then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;
      if No_Split and then Mode /= 'b' then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, "-n");
         return;
      end if;
      if (Has_Delimiter or else Suppress) and then Mode /= 'f' then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Field_Option);
         return;
      end if;
      if Context.Argument_Count < First_File then
         Cut_File ("-", All_Ok);
      else
         for I in First_File .. Context.Argument_Count loop
            declare
               Ok : Boolean;
            begin
               Cut_File (Context.Argument (I), Ok);
               All_Ok := All_Ok and Ok;
            end;
         end loop;
      end if;
      Result.Status :=
        (if All_Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

   function Selected (Ranges : Range_Vectors.Vector; Position : Positive) return Boolean is
   begin
      for Item of Ranges loop
         if Posix_Tools.Text.Cut_Fields.Contains_Position (Item, Position) then
            return True;
         end if;
      end loop;
      return False;
   end Selected;

   function Selected_Characters (Ranges : Range_Vectors.Vector; Line : String) return String is
      Output   : Unbounded_String;
      Index    : Positive := Line'First;
      Position : Positive := 1;
   begin
      while Index <= Line'Last loop
         declare
            Width : constant Positive := Character_Width (Line, Index);
         begin
            if Selected (Ranges, Position) then
               Append (Output, Line (Index .. Index + Width - 1));
            end if;
            Index := Index + Width;
            Position := Position + 1;
         end;
      end loop;
      return To_String (Output);
   end Selected_Characters;

   function Whole_Character_Bytes (Ranges : Range_Vectors.Vector; Line : String) return String is
      Length : constant Natural := Line'Length;
      --  Offsets are one-based byte positions within Line.
      Starts : array (1 .. Length) of Positive;
      Ends   : array (1 .. Length) of Positive;
      Keep   : array (1 .. Length) of Boolean := [others => False];
      Output : Unbounded_String;
      Offset : Positive := 1;
   begin
      while Offset <= Length loop
         declare
            Width : constant Positive := Character_Width (Line, Line'First + Offset - 1);
         begin
            for I in Offset .. Offset + Width - 1 loop
               Starts (I) := Offset;
               Ends (I) := Offset + Width - 1;
            end loop;
            Offset := Offset + Width;
         end;
      end loop;

      for Item of Ranges loop
         if Item.First <= Length then
            declare
               Low  : constant Positive := Starts (Item.First);
               High : Natural := (if Item.Last = 0 then Length else Natural'Min (Item.Last, Length));
            begin
               if Ends (High) /= High then
                  High := Starts (High) - 1;
               end if;
               for I in Low .. High loop
                  Keep (I) := True;
               end loop;
            end;
         end if;
      end loop;

      for I in Keep'Range loop
         if Keep (I) then
            Append (Output, Line (Line'First + I - 1));
         end if;
      end loop;
      return To_String (Output);
   end Whole_Character_Bytes;
end Posix_Tools.Commands.Cut;
