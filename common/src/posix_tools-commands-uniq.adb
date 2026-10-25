with Ada.Containers;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Commands.Text_Helpers.Folding;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Uniq is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   LF : constant Character := Character'Val (10);

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

   --  The filtered output for Lines.
   function Filter_Lines
     (Options : Run_Options;
      Locale  : String;
      Lines   : String_Vectors.Vector) return String;

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

   function Filter_Lines
     (Options : Run_Options;
      Locale  : String;
      Lines   : String_Vectors.Vector) return String
   is
      Output       : Unbounded_String;
      Previous     : Natural := 0;
      Previous_Key : Unbounded_String;
      Count        : Natural := 0;

      procedure Emit_Group;

      --  POSIX uniq: -d suppresses lines that are not repeated and -u lines
      --  that are, so with both nothing is written.
      procedure Emit_Group is
         Should_Emit : constant Boolean :=
           (if Options.Duplicates and then Count = 1 then False
            elsif Options.Unique_Only and then Count > 1 then False
            else True);
      begin
         if Should_Emit then
            if Options.Counts then
               Append (Output, Count_Field (Count) & " ");
            end if;
            Append (Output, Lines (Previous) & LF);
         end if;
      end Emit_Group;
   begin
      for I in 1 .. Natural (Lines.Length) loop
         declare
            Key : constant String := Comparison_Key (Options, Locale, Lines (I));
         begin
            if Previous > 0 and then Key = To_String (Previous_Key) then
               Count := Count + 1;
            else
               if Previous > 0 then
                  Emit_Group;
               end if;
               Previous := I;
               Previous_Key := To_Unbounded_String (Key);
               Count := 1;
            end if;
         end;
      end loop;
      if Previous > 0 then
         Emit_Group;
      end if;
      return To_String (Output);
   end Filter_Lines;

   function Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Options : out Run_Options) return Boolean
   is
      Skip_Next : Boolean := False;

      function Set_Skip (Option : Character; Text : String) return Boolean;

      function Set_Skip (Option : Character; Text : String) return Boolean is
         Value : Natural;
      begin
         if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
           (Context, Result, Text, (if Option = 'f' then "field count" else "character count"), Value)
         then
            return False;
         elsif Option = 'f' then
            Options.Skip_Fields := Value;
         else
            Options.Skip_Chars := Value;
         end if;
         return True;
      end Set_Skip;
   begin
      Options := (others => <>);
      Result.Status := Posix_Tools.Exit_Status.Success;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Skip_Next then
               Skip_Next := False;
            elsif not Options.Files.Is_Empty then
               Options.Files.Append (Arg);
            elsif Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Options.Files.Append (Context.Argument (J));
               end loop;
               exit;
            elsif Arg in "-f" | "-s" and then I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "missing option argument '" & Arg & "'");
               return False;
            elsif Arg'Length >= 2 and then Arg (Arg'First .. Arg'First + 1) in "-f" | "-s" then
               if not Set_Skip
                 (Arg (Arg'First + 1),
                  (if Arg'Length = 2 then Context.Argument (I + 1) else Arg (Arg'First + 2 .. Arg'Last)))
               then
                  return False;
               end if;
               Skip_Next := Arg'Length = 2;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'c' => Options.Counts := True;
                     when 'd' => Options.Duplicates := True;
                     when 'i' => Options.Fold_Case := True;
                     when 'u' => Options.Unique_Only := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "unknown option '-" & Ch & "'");
                        return False;
                  end case;
               end loop;
            else
               Options.Files.Append (Arg);
            end if;
         end;
      end loop;

      if Options.Files.Length > 2 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Options.Files.Element (3) & "'");
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
         Text : constant String :=
           (if Options.Files.Is_Empty or else Options.Files.Element (1) = "-"
            then Posix_Tools.Commands.File_Helpers.Streaming.Read_Standard_Input (Context)
            else Posix_Tools.Commands.File_Helpers.Streaming.Read_File (Context, Options.Files.Element (1), Ok));
      begin
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         declare
            Output : constant String :=
              Filter_Lines
                (Options, Context.Effective_Locale, Posix_Tools.Streams.Lines.Split_LF_Records (Text));
         begin
            if Options.Files.Length = 2 then
               Posix_Tools.Host_Adapters.File_System.Write_File (Options.Files.Element (2), Output, False, Ok);
               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Options.Files.Element (2),
                     "posix_tools.diagnostic.file.write_failed", "cannot write file");
               end if;
            else
               Context.Put (Output);
            end if;
         end;
      end;

      Result.Status :=
        (if Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Uniq;
