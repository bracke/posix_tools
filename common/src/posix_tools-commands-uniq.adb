with Ada.Containers;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
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

   procedure Set_Success
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Set_Success;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Files       : String_Vectors.Vector;
      Counts      : Boolean := False;
      Duplicates  : Boolean := False;
      Fold_Case   : Boolean := False;
      Unique_Only : Boolean := False;
      Skip_Fields : Natural := 0;
      Skip_Chars  : Natural := 0;
      Ok          : Boolean := True;
      Skip_Next   : Boolean := False;
      Parsing_Operands : Boolean := False;

      function Comparison_Key (Line : String) return String is
         Position : Natural := Line'First;

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
      begin
         for Field in 1 .. Skip_Fields loop
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

         for Ch in 1 .. Skip_Chars loop
            exit when Position > Line'Last;
            Advance_Character;
         end loop;

         if Position > Line'Last then
            return "";
         else
            declare
               Text_Key : constant String :=
                 (if Fold_Case
                  then Posix_Tools.Commands.Text_Helpers.Folded_Sort_Text
                    (Line (Position .. Line'Last))
                  else Line (Position .. Line'Last));
            begin
               return Posix_Tools.Commands.Text_Helpers.Locale_Sort_Text
                 (Context.Effective_Locale, Text_Key);
            end;
         end if;
      end Comparison_Key;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Skip_Next then
               Skip_Next := False;
            elsif not Parsing_Operands and then Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Files.Append (Context.Argument (J));
               end loop;
               exit;
            elsif not Parsing_Operands and then Arg = "-f" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-f'");
                  return;
               end if;
               if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
                 (Context, Result, Context.Argument (I + 1), "field count", Skip_Fields)
               then
                  return;
               end if;
               Skip_Next := True;
            elsif not Parsing_Operands
              and then Arg'Length > 2
              and then Arg (Arg'First .. Arg'First + 1) = "-f"
            then
               if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
                 (Context, Result, Arg (Arg'First + 2 .. Arg'Last), "field count", Skip_Fields)
               then
                  return;
               end if;
            elsif not Parsing_Operands and then Arg = "-s" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-s'");
                  return;
               end if;
               if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
                 (Context, Result, Context.Argument (I + 1), "character count", Skip_Chars)
               then
                  return;
               end if;
               Skip_Next := True;
            elsif not Parsing_Operands
              and then Arg'Length > 2
              and then Arg (Arg'First .. Arg'First + 1) = "-s"
            then
               if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
                 (Context, Result, Arg (Arg'First + 2 .. Arg'Last), "character count", Skip_Chars)
               then
                  return;
               end if;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'c' => Counts := True;
                     when 'd' => Duplicates := True;
                     when 'i' => Fold_Case := True;
                     when 'u' => Unique_Only := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Files.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Files.Length > 2 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Files.Element (3) & "'");
         return;
      end if;

      declare
         Text : constant String :=
           (if Files.Length = 0 or else Files.Element (1) = "-"
            then Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context)
            else Posix_Tools.Commands.File_Helpers.Read_File
              (Context, Files.Element (1), Ok));
         Lines   : constant String_Vectors.Vector :=
           Posix_Tools.Streams.Lines.Split_LF_Records (Text);
         Output  : Unbounded_String;
         Written : Boolean;

         function Count_Field (Count : Natural) return String is
            Raw : constant String :=
              Posix_Tools.Text.Numeric_Images.Natural_Image (Count);
         begin
            if Raw'Length >= 7 then
               return Raw;
            else
               declare
                  Padding : String (1 .. 7 - Raw'Length);
               begin
                  for I in Padding'Range loop
                     Padding (I) := ' ';
                  end loop;
                  return Padding & Raw;
               end;
            end if;
         end Count_Field;

         procedure Emit_Group (Line : String; Count : Natural) is
            Should_Emit : constant Boolean :=
              (if Duplicates then Count > 1 elsif Unique_Only then Count = 1 else True);
         begin
            if Should_Emit then
               if Counts then
                  Append (Output, Count_Field (Count) & " ");
               end if;
               Append (Output, Line & LF);
            end if;
         end Emit_Group;
      begin
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         if Lines.Length > 0 then
            declare
               Previous : Unbounded_String := To_Unbounded_String (Lines.Element (1));
               Previous_Key : Unbounded_String :=
                 To_Unbounded_String (Comparison_Key (Lines.Element (1)));
               Count : Natural := 1;
            begin
               for I in 2 .. Natural (Lines.Length) loop
                  if Comparison_Key (Lines.Element (I)) = To_String (Previous_Key) then
                     Count := Count + 1;
                  else
                     Emit_Group (To_String (Previous), Count);
                     Previous := To_Unbounded_String (Lines.Element (I));
                     Previous_Key := To_Unbounded_String (Comparison_Key (Lines.Element (I)));
                     Count := 1;
                  end if;
               end loop;
               Emit_Group (To_String (Previous), Count);
            end;
         end if;

         if Files.Length = 2 then
            Posix_Tools.Commands.File_Helpers.Write_File
              (Files.Element (2), To_String (Output), False, Written);
            Ok := Written;
         else
            Context.Put (To_String (Output));
         end if;
      end;
      Set_Success (Context, Result);
      if not Ok or else Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;
end Posix_Tools.Commands.Uniq;
