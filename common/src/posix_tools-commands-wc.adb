with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Streams.Counting;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.UTF_8;
with Posix_Tools.Wc_Fields;

package body Posix_Tools.Commands.Wc is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   subtype Counts is Posix_Tools.Streams.Counting.Counts;

   procedure Count_Buffer
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      State   : in out Posix_Tools.Streams.Counting.Counter)
   is
   begin
      if Last >= Buffer'First then
         Posix_Tools.Streams.Counting.Process (State, Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
      end if;
   end Count_Buffer;

   procedure Count_File
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Single_Byte : Boolean;
      Fields    : Posix_Tools.Wc_Fields.Count_Selection;
      Result    : out Counts;
      Ok        : out Boolean)
   is
      State : Posix_Tools.Streams.Counting.Counter;
      Simple_Counts : constant Boolean :=
        not Fields.Words
        and then not Fields.Max_Line_Length
        and then (not Fields.Characters or else Single_Byte);
      Character_Counts : constant Boolean :=
        not Fields.Words
        and then not Fields.Max_Line_Length
        and then Fields.Characters
        and then not Single_Byte;
      Word_Counts : constant Boolean :=
        Fields.Words and then not Fields.Max_Line_Length;
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      In_Word : Boolean := False;

      procedure Count_Characters
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset);

      procedure Count_Words
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset);

      procedure Increment (Value : in out Posix_Tools.Streams.Counting.Count_Value) is
      begin
         Value := Posix_Tools.Streams.Counting.Saturating_Add (Value, 1);
      end Increment;

      procedure Count_Characters
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset)
      is
         All_ASCII : Boolean := Posix_Tools.Text.UTF_8.Is_Initial (Decoder);
         Line_Count : Natural := 0;
      begin
         if Last < Buffer'First then
            return;
         end if;

         if All_ASCII then
            for I in Buffer'First .. Last loop
               if Buffer (I) > 16#7F# then
                  All_ASCII := False;
                  exit;
               elsif Fields.Lines and then Buffer (I) = 10 then
                  Line_Count := Line_Count + 1;
               end if;
            end loop;
            if All_ASCII then
               Result.Characters := Posix_Tools.Streams.Counting.Saturating_Add
                 (Result.Characters,
                  Posix_Tools.Streams.Counting.Count_Value
                    (Last - Buffer'First + 1));
               Result.Lines := Posix_Tools.Streams.Counting.Saturating_Add
                 (Result.Lines,
                  Posix_Tools.Streams.Counting.Count_Value (Line_Count));
               return;
            end if;
         end if;

         for I in Buffer'First .. Last loop
            declare
               Byte       : constant Natural := Natural (Buffer (I));
               Status     : Posix_Tools.Text.UTF_8.Decode_Status;
               Code_Point : Long_Long_Integer;
               Consumed   : Boolean;
            begin
               if Fields.Lines and then Byte = 10 then
                  Increment (Result.Lines);
               end if;

               if Byte <= 16#7F# and then Posix_Tools.Text.UTF_8.Is_Initial (Decoder) then
                  Increment (Result.Characters);
               else
                  Posix_Tools.Text.UTF_8.Decode
                    (Decoder, Byte, Status, Code_Point, Consumed);
                  if Status in Posix_Tools.Text.UTF_8.Complete | Posix_Tools.Text.UTF_8.Invalid then
                     Increment (Result.Characters);
                  end if;
                  if not Consumed then
                     Posix_Tools.Text.UTF_8.Decode
                       (Decoder, Byte, Status, Code_Point);
                     if Status in Posix_Tools.Text.UTF_8.Complete | Posix_Tools.Text.UTF_8.Invalid then
                        Increment (Result.Characters);
                     end if;
                  end if;
               end if;
            end;
         end loop;
      end Count_Characters;

      procedure Count_Words
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset)
      is
         Character_Count : Natural := 0;
         Line_Count      : Natural := 0;
         Word_Count      : Natural := 0;
         procedure Note (Code_Point : Long_Long_Integer; Valid : Boolean := True);

         procedure Note (Code_Point : Long_Long_Integer; Valid : Boolean := True) is
            Is_Whitespace : constant Boolean :=
              Valid
              and then
                (if Code_Point <= 16#7F#
                 then Code_Point in 9 .. 13 | 32
                 else Posix_Tools.Text.Classification.Is_Whitespace (Code_Point));
         begin
            if Fields.Characters and then not Single_Byte then
               Character_Count := Character_Count + 1;
            end if;
            if Is_Whitespace then
               In_Word := False;
            elsif not In_Word then
               Word_Count := Word_Count + 1;
               In_Word := True;
            end if;
         end Note;
      begin
         if Last < Buffer'First then
            return;
         end if;

         for I in Buffer'First .. Last loop
            declare
               Byte       : constant Natural := Natural (Buffer (I));
               Status     : Posix_Tools.Text.UTF_8.Decode_Status;
               Code_Point : Long_Long_Integer;
               Consumed   : Boolean;
            begin
               if Fields.Lines and then Byte = 10 then
                  Line_Count := Line_Count + 1;
               end if;

               if Single_Byte then
                  if Byte <= 16#7F# and then Byte in 9 .. 13 | 32 then
                     In_Word := False;
                  elsif not In_Word then
                     Word_Count := Word_Count + 1;
                     In_Word := True;
                  end if;
               elsif Byte <= 16#7F#
                 and then Posix_Tools.Text.UTF_8.Is_Initial (Decoder)
               then
                  if Fields.Characters then
                     Character_Count := Character_Count + 1;
                  end if;
                  if Byte in 9 .. 13 | 32 then
                     In_Word := False;
                  elsif not In_Word then
                     Word_Count := Word_Count + 1;
                     In_Word := True;
                  end if;
               else
                  Posix_Tools.Text.UTF_8.Decode
                    (Decoder, Byte, Status, Code_Point, Consumed);
                  if Status = Posix_Tools.Text.UTF_8.Complete then
                     Note (Code_Point);
                  elsif Status = Posix_Tools.Text.UTF_8.Invalid then
                     Note (0, Valid => False);
                  end if;
                  if not Consumed then
                     Posix_Tools.Text.UTF_8.Decode
                       (Decoder, Byte, Status, Code_Point);
                     if Status = Posix_Tools.Text.UTF_8.Complete then
                        Note (Code_Point);
                     elsif Status = Posix_Tools.Text.UTF_8.Invalid then
                        Note (0, Valid => False);
                     end if;
                  end if;
               end if;
            end;
         end loop;

         Result.Lines := Posix_Tools.Streams.Counting.Saturating_Add
           (Result.Lines,
            Posix_Tools.Streams.Counting.Count_Value (Line_Count));
         Result.Words := Posix_Tools.Streams.Counting.Saturating_Add
           (Result.Words,
            Posix_Tools.Streams.Counting.Count_Value (Word_Count));
         if Fields.Characters then
            Result.Characters := Posix_Tools.Streams.Counting.Saturating_Add
              (Result.Characters,
               Posix_Tools.Streams.Counting.Count_Value
                 (if Single_Byte
                  then Last - Buffer'First + 1
                  else Ada.Streams.Stream_Element_Offset (Character_Count)));
         end if;
      end Count_Words;

      procedure Count_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Context);
      begin
         if Simple_Counts or else Character_Counts or else Word_Counts then
            if Last >= Buffer'First then
               Result.Bytes := Posix_Tools.Streams.Counting.Saturating_Add
                 (Result.Bytes,
                  Posix_Tools.Streams.Counting.Count_Value
                    (Last - Buffer'First + 1));
               if Word_Counts then
                  Count_Words (Buffer, Last);
               elsif Character_Counts then
                  Count_Characters (Buffer, Last);
               elsif Fields.Lines then
                  for I in Buffer'First .. Last loop
                     if Buffer (I) = 10 then
                        Result.Lines :=
                          Posix_Tools.Streams.Counting.Saturating_Add
                            (Result.Lines, 1);
                     end if;
                  end loop;
               end if;
            end if;
         else
            Count_Buffer (Buffer, Last, State);
         end if;
      end Count_Chunk;

      procedure Count_Chunks is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
        (Action        => Count_Chunk,
         Buffer_Length =>
           Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
   begin
      Result := (others => 0);
      if Single_Byte then
         Posix_Tools.Streams.Counting.Count_Single_Bytes (State);
      end if;
      Count_Chunks (Context, File_Name, Ok);
      if not Ok then
         return;
      end if;

      if Simple_Counts then
         if Fields.Characters then
            Result.Characters := Result.Bytes;
         end if;
      elsif Character_Counts or else Word_Counts then
         declare
            Status : Posix_Tools.Text.UTF_8.Decode_Status;
         begin
            if Single_Byte then
               Status := Posix_Tools.Text.UTF_8.Complete;
            else
               Posix_Tools.Text.UTF_8.Finish (Decoder, Status);
            end if;
            if Status = Posix_Tools.Text.UTF_8.Invalid then
               if Word_Counts then
                  if Fields.Characters then
                     Increment (Result.Characters);
                  end if;
                  if not In_Word then
                     Increment (Result.Words);
                  end if;
               else
                  Increment (Result.Characters);
               end if;
            end if;
         end;
      else
         Posix_Tools.Streams.Counting.Finish_Text (State);
         Result := Posix_Tools.Streams.Counting.Snapshot (State);
      end if;
   end Count_File;

   procedure Print_Counts
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Output  : in out Posix_Tools.Commands.Helpers.Output_Buffer;
      C       : Counts;
      Name    : String;
      Show_C  : Boolean;
      Show_L  : Boolean;
      Show_M  : Boolean;
      Show_W  : Boolean;
      Show_Max_Line_Length : Boolean)
   is
      Text : Unbounded_String;
   begin
      if Show_L then
         Append (Text, " " & Posix_Tools.Wc_Fields.Count_Image (C.Lines));
      end if;
      if Show_W then
         Append (Text, " " & Posix_Tools.Wc_Fields.Count_Image (C.Words));
      end if;
      if Show_C then
         Append (Text, " " & Posix_Tools.Wc_Fields.Count_Image (C.Bytes));
      end if;
      if Show_M then
         Append (Text, " " & Posix_Tools.Wc_Fields.Count_Image (C.Characters));
      end if;
      if Show_Max_Line_Length then
         Append (Text, " " & Posix_Tools.Wc_Fields.Count_Image (C.Max_Line_Length));
      end if;
      if Name /= "" then
         Append (Text, " " & Name);
      end if;

      declare
         Rendered : constant String := To_String (Text);
      begin
         if Rendered /= "" and then Rendered (Rendered'First) = ' ' then
            Posix_Tools.Commands.Helpers.Buffered_Put_Line
              (Output, Context,
               Rendered (Rendered'First + 1 .. Rendered'Last));
         else
            Posix_Tools.Commands.Helpers.Buffered_Put_Line
              (Output, Context, Rendered);
         end if;
      end;
   end Print_Counts;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Show_C     : Boolean := False;
      Show_L     : Boolean := False;
      Show_M     : Boolean := False;
      Show_W     : Boolean := False;
      Show_Max_Line_Length : Boolean := False;
      First_File : Positive;
      Valid      : Boolean;
      --  In a single-byte locale, such as C, each byte is a character.
      Single_Byte : constant Boolean :=
        not Posix_Tools.Commands.Text_Helpers.Collation.Is_Multibyte_Locale
          (Context.Category_Locale (Posix_Tools.Commands.Contexts.Character_Classification));
      C          : Counts;
      Total      : Counts := (others => 0);
      Ok         : Boolean;
      All_Ok     : Boolean := True;
      Successful : Natural := 0;
      Output     : Posix_Tools.Commands.Helpers.Output_Buffer;

      function Selection return Posix_Tools.Wc_Fields.Count_Selection is
      begin
         return
           (Lines      => Show_L,
            Words      => Show_W,
            Bytes      => Show_C,
            Characters => Show_M,
            Max_Line_Length => Show_Max_Line_Length);
      end Selection;

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Value, Result);
      begin
         case Name is
            when 'c' => Show_C := True;
            when 'l' => Show_L := True;
            when 'm' => Show_M := True;
            when 'w' => Show_W := True;
            when others => Show_Max_Line_Length := True;
         end case;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "clmwL", "", First_File, Valid);
      if not Valid then
         return;
      end if;

      if not (Show_C or Show_L or Show_M or Show_W or Show_Max_Line_Length) then
         Show_L := True;
         Show_W := True;
         Show_C := True;
      end if;

      pragma Assert (Posix_Tools.Wc_Fields.Selected_Field_Count (Selection) > 0);

      if First_File > Context.Argument_Count then
         Count_File (Context, "-", Single_Byte, Selection, C, Ok);
         if Ok then
            Print_Counts
              (Context, Output, C, "", Show_C, Show_L, Show_M, Show_W,
               Show_Max_Line_Length);
            Ok := not Context.Output_Failed;
         end if;
         All_Ok := Ok;
      else
         for I in First_File .. Context.Argument_Count loop
            Count_File
              (Context,
               Context.Argument (I),
               Single_Byte,
               Selection,
               C,
               Ok);
            if Ok then
               Print_Counts
                 (Context, Output, C, Context.Argument (I), Show_C, Show_L,
                  Show_M, Show_W, Show_Max_Line_Length);
               if Context.Output_Failed then
                  Ok := False;
               else
                  Successful := Successful + 1;
                  Total.Lines := Total.Lines + C.Lines;
                  Total.Words := Total.Words + C.Words;
                  Total.Bytes := Total.Bytes + C.Bytes;
                  Total.Characters := Total.Characters + C.Characters;
                  if C.Max_Line_Length > Total.Max_Line_Length then
                     Total.Max_Line_Length := C.Max_Line_Length;
                  end if;
               end if;
            end if;
            All_Ok := All_Ok and Ok;
            exit when Context.Output_Failed;
         end loop;

         if not Context.Output_Failed
           and then Context.Argument_Count - First_File + 1 > 1
           and then Successful > 0
         then
            Print_Counts
              (Context, Output, Total, "total", Show_C, Show_L, Show_M,
               Show_W, Show_Max_Line_Length);
            if Context.Output_Failed then
               All_Ok := False;
            end if;
         end if;
      end if;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Wc;
