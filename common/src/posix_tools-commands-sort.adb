with Ada.Containers;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Sort_Keys;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Sort_Modifiers;

package body Posix_Tools.Commands.Sort is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;

   LF : constant Character := Character'Val (10);

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;
   package Sort_Key_Vectors renames Posix_Tools.Commands.Sort_Keys.Sort_Key_Vectors;
   subtype Sort_Key_Definition is Posix_Tools.Commands.Sort_Keys.Sort_Key_Definition;

   procedure Set_Success
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
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
      Output_Path : Unbounded_String;
      Reverse_Order : Boolean := False;
      Fold_Case   : Boolean := False;
      Ignore_Leading_Blanks : Boolean := False;
      Dictionary_Order : Boolean := False;
      Ignore_Nonprinting : Boolean := False;
      Numeric_Sort : Boolean := False;
      Stable_Sort  : Boolean := False;
      Unique      : Boolean := False;
      Check_Only  : Boolean := False;
      Keys        : Sort_Key_Vectors.Vector;
      Key_Field   : constant Positive := 1;
      Key_End_Field : constant Natural := 0;
      Key_Character : constant Positive := 1;
      Key_End_Character : constant Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Text        : Unbounded_String;
      Ok          : Boolean := True;
      Skip_Next   : Boolean := False;
      Parsing_Operands : Boolean := False;
      Locale      : constant String := Context.Effective_Locale;

      function Parse_Sort_Key
         (Text : String;
          Key  : out Sort_Key_Definition) return Boolean
      is
         Parsed : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Key (Text);
      begin
         Key := (others => <>);
         if not Parsed.Valid then
            return False;
         end if;

         Key :=
           (Field_Start => Parsed.Field_Start,
            Field_End => Parsed.Field_End,
            Character_Start => Parsed.Character_Start,
            Character_End => Parsed.Character_End,
            Fold_Case => Parsed.Fold_Case,
            Numeric_Sort => Parsed.Numeric_Sort,
            Ignore_Leading_Blanks => Parsed.Ignore_Leading_Blanks,
            Dictionary_Order => Parsed.Dictionary_Order,
            Ignore_Nonprinting => Parsed.Ignore_Nonprinting,
            Reverse_Order => Parsed.Reverse_Order);
         return True;
      end Parse_Sort_Key;
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
            elsif not Parsing_Operands and then Arg = "-o" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-o'");
                  return;
               end if;
               Output_Path := To_Unbounded_String (Context.Argument (I + 1));
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-o" then
               Output_Path := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
            elsif not Parsing_Operands and then Arg = "-k" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-k'");
                  return;
               end if;
               declare
                  Key : Sort_Key_Definition;
               begin
                  if Parse_Sort_Key (Context.Argument (I + 1), Key) then
                     Keys.Append (Key);
                  else
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Context.Argument (I + 1) & "'");
                     return;
                  end if;
               end;
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-k" then
               declare
                  Key : Sort_Key_Definition;
                  Key_Text : constant String := Arg (Arg'First + 2 .. Arg'Last);
               begin
                  if Parse_Sort_Key (Key_Text, Key) then
                     Keys.Append (Key);
                  else
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Key_Text & "'");
                     return;
                  end if;
               end;
            elsif not Parsing_Operands and then Arg = "-t" then
               if I = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-t'");
                  return;
               elsif Context.Argument (I + 1)'Length /= 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (I + 1) & "'");
                  return;
               end if;
               Field_Separator := Context.Argument (I + 1) (Context.Argument (I + 1)'First);
               Has_Field_Separator := True;
               Skip_Next := True;
            elsif not Parsing_Operands and then Arg'Length = 3 and then Arg (Arg'First .. Arg'First + 1) = "-t" then
               Field_Separator := Arg (Arg'Last);
               Has_Field_Separator := True;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'c' | 'C' => Check_Only := True;
                     when 'b' => Ignore_Leading_Blanks := True;
                     when 'd' => Dictionary_Order := True;
                     when 'f' => Fold_Case := True;
                     when 'i' => Ignore_Nonprinting := True;
                     when 'm' => null;
                     when 'n' => Numeric_Sort := True;
                     when 'r' => Reverse_Order := True;
                     when 's' => Stable_Sort := True;
                     when 'u' => Unique := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Files.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Files.Length = 0 then
         Text :=
           To_Unbounded_String
             (Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context));
      else
         for I in 1 .. Natural (Files.Length) loop
            if Files.Element (I) = "-" then
               Append (Text, Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context));
            else
               Append
                 (Text,
                  Posix_Tools.Commands.File_Helpers.Read_File
                    (Context, Files.Element (I), Ok));
            end if;
            if not Ok then
               Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               return;
            end if;
         end loop;
      end if;
      declare
         Lines : String_Vectors.Vector :=
           Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Text));
         Output : Unbounded_String;
         Previous : Unbounded_String;
         First : Boolean := True;
         Written : Boolean;
      begin
         if Check_Only then
            Result.Status :=
              (if Posix_Tools.Commands.Sort_Keys.Lines_Are_Sorted
                    (Lines,
                     Keys,
                     Fold_Case,
                     Numeric_Sort,
                     Ignore_Leading_Blanks,
                     Reverse_Order,
                     Unique,
                     Stable_Sort,
                     Dictionary_Order,
                     Ignore_Nonprinting,
                     Key_Field,
                     Key_End_Field,
                     Key_Character,
                     Key_End_Character,
                     Field_Separator,
                     Has_Field_Separator,
                     Locale)
               then Posix_Tools.Exit_Status.Success
               else Posix_Tools.Exit_Status.Operational_Failure);
            return;
         end if;

         Posix_Tools.Commands.Sort_Keys.Sort_Lines
           (Lines,
            Keys,
            Fold_Case,
            Numeric_Sort,
            Ignore_Leading_Blanks,
            Stable_Sort,
            Dictionary_Order,
            Ignore_Nonprinting,
            Key_Field,
            Key_End_Field,
            Key_Character,
            Key_End_Character,
            Field_Separator,
            Has_Field_Separator,
            Locale);
         if Reverse_Order and then Lines.Length > 0 then
            for I in reverse 1 .. Natural (Lines.Length) loop
               if (not Unique)
                 or else First
                 or else not Posix_Tools.Commands.Sort_Keys.Sort_Keys_Equal
                   (Lines.Element (I),
                    To_String (Previous),
                    Keys,
                    Fold_Case,
                    Ignore_Leading_Blanks,
                    Dictionary_Order,
                    Ignore_Nonprinting,
                    Key_Field,
                    Key_End_Field,
                    Key_Character,
                    Key_End_Character,
                    Field_Separator,
                    Has_Field_Separator,
                    Locale)
               then
                  Append (Output, Lines.Element (I) & LF);
               end if;
               Previous := To_Unbounded_String (Lines.Element (I));
               First := False;
            end loop;
         else
            for Line of Lines loop
               if (not Unique)
                 or else First
                 or else not Posix_Tools.Commands.Sort_Keys.Sort_Keys_Equal
                   (Line,
                    To_String (Previous),
                    Keys,
                    Fold_Case,
                    Ignore_Leading_Blanks,
                    Dictionary_Order,
                    Ignore_Nonprinting,
                    Key_Field,
                    Key_End_Field,
                    Key_Character,
                    Key_End_Character,
                    Field_Separator,
                    Has_Field_Separator,
                    Locale)
               then
                  Append (Output, Line & LF);
               end if;
               Previous := To_Unbounded_String (Line);
               First := False;
            end loop;
         end if;

         if Length (Output_Path) = 0 then
            Context.Put (To_String (Output));
         else
            Posix_Tools.Commands.File_Helpers.Write_File
              (To_String (Output_Path), To_String (Output), False, Written);
            Ok := Written;
         end if;
      end;
      Set_Success (Context, Result);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;

end Posix_Tools.Commands.Sort;
