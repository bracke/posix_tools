with Ada.Containers;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Commands.Text_Helpers.Folding;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Output_Files;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Uniq is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   LF : constant Character := Character'Val (10);
   Output_Chunk_Size : constant := 64 * 1024;

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;

   type Run_Options is record
      Files       : String_Vectors.Vector;
      Counts      : Boolean := False;
      Duplicates  : Boolean := False;
      Fold_Case   : Boolean := False;
      Unique_Only : Boolean := False;
      Skip_Fields : Natural := 0;
      Skip_Chars  : Natural := 0;
   end record;

   --  What lines are compared by: the line after -f fields and -s characters,
   --  case-folded for -i, as a collation key of the locale. In the C and POSIX
   --  locales that key is the bytes themselves.
   function Comparison_Key (Options : Run_Options; Locale, Line : String) return String;

   function Count_Field (Count : Natural) return String;

   --  Parses the command line into Options; False after a usage error.
   function Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Options : out Run_Options) return Boolean;

   function Comparison_Key (Options : Run_Options; Locale, Line : String) return String is
      Position : Natural := Line'First;

      procedure Advance_Character;

      function Is_Field_Separator_At (Index : Positive; Width : out Natural) return Boolean;

      procedure Advance_Character is
         Decoder    : Posix_Tools.Text.UTF_8.Decoder;
         Status     : Posix_Tools.Text.UTF_8.Decode_Status;
         Code_Point : Long_Long_Integer;
      begin
         if Position > Line'Last then
            return;
         end if;

         for I in Position .. Line'Last loop
            Posix_Tools.Text.UTF_8.Decode
              (Decoder, Character'Pos (Line (I)), Status, Code_Point);
            if Status = Posix_Tools.Text.UTF_8.Complete then
               Position := I + 1;
               return;
            elsif Status = Posix_Tools.Text.UTF_8.Invalid then
               Position := Position + 1;
               return;
            end if;
         end loop;

         Position := Position + 1;
      end Advance_Character;

      function Is_Field_Separator_At (Index : Positive; Width : out Natural) return Boolean is
         Decoder    : Posix_Tools.Text.UTF_8.Decoder;
         Status     : Posix_Tools.Text.UTF_8.Decode_Status;
         Code_Point : Long_Long_Integer;
      begin
         Width := 1;
         for I in Index .. Line'Last loop
            Posix_Tools.Text.UTF_8.Decode
              (Decoder, Character'Pos (Line (I)), Status, Code_Point);
            if Status = Posix_Tools.Text.UTF_8.Complete then
               Width := I - Index + 1;
               return Posix_Tools.Text.Classification.Is_Whitespace (Code_Point);
            elsif Status = Posix_Tools.Text.UTF_8.Invalid then
               Width := 1;
               return Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Line (Index));
            end if;
         end loop;

         return Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Line (Index));
      end Is_Field_Separator_At;
   begin
      for Field in 1 .. Options.Skip_Fields loop
         while Position <= Line'Last loop
            declare
               Width : Natural;
            begin
               exit when not Is_Field_Separator_At (Position, Width);
               Position := Position + Width;
            end;
         end loop;

         while Position <= Line'Last loop
            declare
               Width : Natural;
            begin
               exit when Is_Field_Separator_At (Position, Width);
               Position := Position + Width;
            end;
         end loop;
      end loop;

      for Ch in 1 .. Options.Skip_Chars loop
         exit when Position > Line'Last;
         Advance_Character;
      end loop;

      if Position > Line'Last then
         return "";
      end if;

      declare
         Text_Key : constant String :=
           (if Options.Fold_Case
            then Posix_Tools.Commands.Text_Helpers.Folding.Folded_Sort_Text (Line (Position .. Line'Last))
            else Line (Position .. Line'Last));
      begin
         return Posix_Tools.Commands.Text_Helpers.Collation.Locale_Sort_Text (Locale, Text_Key);
      end;
   end Comparison_Key;

   function Count_Field (Count : Natural) return String is
      Raw : constant String := Posix_Tools.Text.Numeric_Images.Natural_Image (Count);
   begin
      if Raw'Length >= 7 then
         return Raw;
      end if;
      return [1 .. 7 - Raw'Length => ' '] & Raw;
   end Count_Field;

   function Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Options : out Run_Options) return Boolean
   is
      First : Positive;
      Valid : Boolean;

      function Set_Skip
        (Result : in out Posix_Tools.Commands.Results.Result;
         Option : Character;
         Text   : String) return Boolean;

      function Set_Skip
        (Result : in out Posix_Tools.Commands.Results.Result;
         Option : Character;
         Text   : String) return Boolean
      is
         Value : Natural;
      begin
         if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
           (Context, Result, Text, (if Option = 'f' then Invalid_Field_Count else Invalid_Character_Count), Value)
         then
            return False;
         elsif Option = 'f' then
            Options.Skip_Fields := Value;
         else
            Options.Skip_Chars := Value;
         end if;
         return True;
      end Set_Skip;

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
      begin
         Valid := True;
         case Name is
            when 'c' => Options.Counts := True;
            when 'd' => Options.Duplicates := True;
            when 'i' => Options.Fold_Case := True;
            when 'u' => Options.Unique_Only := True;
            when others => Valid := Set_Skip (Result, Name, Value);
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      Options := (others => <>);
      Result.Status := Posix_Tools.Exit_Status.Success;

      Parse (Context, Result, "cdfisu", "fs", First, Valid);
      if not Valid then
         return False;
      end if;
      for I in First .. Context.Argument_Count loop
         Options.Files.Append (Context.Argument (I));
      end loop;

      if Options.Files.Length > 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Options.Files.Element (3));
         return False;
      end if;
      return True;
   end Parse_Options;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options : Run_Options;
      Ok      : Boolean := True;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      elsif not Parse_Options (Context, Result, Options) then
         return;
      end if;

      declare
         Locale       : constant String :=
           Context.Category_Locale (Posix_Tools.Commands.Contexts.Collation);
         Input_Name   : constant String :=
           (if Options.Files.Is_Empty or else Options.Files.Element (1) = "-"
            then "-" else Options.Files.Element (1));
         Previous     : Unbounded_String;
         Previous_Key : Unbounded_String;
         Count        : Natural := 0;
         Pending      : Unbounded_String;
         Output       : Posix_Tools.Host_Adapters.Output_Files.Output_File;
         Output_Open  : Boolean := False;
         Partial      : Unbounded_String;
         Direct_Comparison : constant Boolean :=
           not Options.Fold_Case
           and then Options.Skip_Fields = 0
           and then Options.Skip_Chars = 0
           and then Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale (Locale);

         procedure Emit_Group;
         procedure Flush;
         procedure Scan_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);
         procedure Write_Direct (Text : String);
         procedure Write_Previous;
         procedure Take_Line (Line : String);

         procedure Flush is
         begin
            if Length (Pending) = 0 or else not Ok then
               return;
            elsif Output_Open then
               Posix_Tools.Host_Adapters.Output_Files.Write
                 (Output, To_String (Pending), Ok);
               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Options.Files.Element (2),
                     "posix_tools.diagnostic.file.write_failed", "cannot write file");
               end if;
            else
               Context.Put (To_String (Pending));
               Ok := not Context.Output_Failed;
            end if;
            Pending := Null_Unbounded_String;
         end Flush;

         procedure Write_Direct (Text : String) is
         begin
            if not Ok or else Text = "" then
               return;
            elsif Output_Open then
               Posix_Tools.Host_Adapters.Output_Files.Write (Output, Text, Ok);
               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Options.Files.Element (2),
                     "posix_tools.diagnostic.file.write_failed", "cannot write file");
               end if;
            else
               Context.Put (Text);
               Ok := not Context.Output_Failed;
            end if;
         end Write_Direct;

         procedure Write_Previous is
            First : Positive := 1;
         begin
            while Ok and then First <= Length (Previous) loop
               declare
                  Last : constant Natural := Natural'Min
                    (Length (Previous), First + Output_Chunk_Size - 1);
               begin
                  Write_Direct (Slice (Previous, First, Last));
                  First := Last + 1;
               end;
            end loop;
         end Write_Previous;

         procedure Emit_Group is
            Should_Emit : constant Boolean :=
              (if Options.Duplicates and then Count = 1 then False
               elsif Options.Unique_Only and then Count > 1 then False
               else True);
         begin
            if Should_Emit then
               if Length (Previous) >= Output_Chunk_Size then
                  Flush;
                  if Options.Counts then
                     Write_Direct (Count_Field (Count) & " ");
                  end if;
                  Write_Previous;
                  Write_Direct ("" & LF);
               else
                  if Options.Counts then
                     Append (Pending, Count_Field (Count) & " ");
                  end if;
                  Append (Pending, Previous);
                  Append (Pending, LF);
                  if Length (Pending) >= 64 * 1024 then
                     Flush;
                  end if;
               end if;
            end if;
         end Emit_Group;

         procedure Take_Line (Line : String) is
         begin
            if Direct_Comparison then
               if Count > 0 and then Previous = Line then
                  Count := Count + 1;
               else
                  if Count > 0 then
                     Emit_Group;
                  end if;
                  Previous := To_Unbounded_String (Line);
                  Count := 1;
               end if;
            else
               declare
                  Key : constant String := Comparison_Key (Options, Locale, Line);
               begin
                  if Count > 0 and then Key = Previous_Key then
                     Count := Count + 1;
                  else
                     if Count > 0 then
                        Emit_Group;
                     end if;
                     Previous := To_Unbounded_String (Line);
                     Previous_Key := To_Unbounded_String (Key);
                     Count := 1;
                  end if;
               end;
            end if;
         end Take_Line;

         procedure Scan_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Ignored);
            Start : Ada.Streams.Stream_Element_Offset := Buffer'First;
         begin
            if Last < Buffer'First then
               return;
            end if;

            for I in Buffer'First .. Last loop
               if Buffer (I) = Ada.Streams.Stream_Element (10) then
                  if Length (Partial) = 0 then
                     if Start = I then
                        Take_Line ("");
                     else
                        Take_Line
                          (Posix_Tools.Streams.Bytes.To_String
                             (Buffer (Start .. I - 1), I - 1));
                     end if;
                  else
                     if Start < I then
                        Append
                          (Partial,
                           Posix_Tools.Streams.Bytes.To_String
                             (Buffer (Start .. I - 1), I - 1));
                     end if;
                     Take_Line (To_String (Partial));
                     Partial := Null_Unbounded_String;
                  end if;
                  Start := I + 1;
                  exit when not Ok;
               end if;
            end loop;

            if Ok and then Start <= Last then
               Append
                 (Partial,
                  Posix_Tools.Streams.Bytes.To_String
                    (Buffer (Start .. Last), Last));
            end if;
         end Scan_Chunk;

         procedure Iterate is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
             (Action        => Scan_Chunk,
              Buffer_Length =>
                Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
      begin
         if Options.Files.Length = 2 then
            Posix_Tools.Host_Adapters.Output_Files.Open
              (Output, Options.Files.Element (2), False, Ok);
            Output_Open := Ok;
            if not Ok then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Options.Files.Element (2),
                  "posix_tools.diagnostic.file.write_failed", "cannot write file");
            end if;
         end if;
         if Ok then
            Iterate (Context, Input_Name, Ok);
            if Ok and then Length (Partial) > 0 then
               Take_Line (To_String (Partial));
            end if;
         end if;
         if Ok and then Count > 0 then
            Emit_Group;
            Flush;
         end if;
         if Output_Open then
            declare
               Closed : Boolean;
            begin
               Posix_Tools.Host_Adapters.Output_Files.Close (Output, Closed);
               Ok := Ok and Closed;
               if not Closed then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Options.Files.Element (2),
                     "posix_tools.diagnostic.file.write_failed", "cannot write file");
               end if;
            end;
         end if;
      end;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Uniq;
