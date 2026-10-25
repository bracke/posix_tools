with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Sort_Keys;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Sort_Modifiers;

package body Posix_Tools.Commands.Sort is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;
   package Sort_Keys renames Posix_Tools.Commands.Sort_Keys;

   type Run_Options is record
      Files       : String_Vectors.Vector;
      Output_Path : Unbounded_String;
      Check_Only  : Boolean := False;
      Sorting     : Sort_Keys.Sort_Options;
   end record;

   --  Parses the command line into Options; False after a usage error.
   function Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Options : out Run_Options) return Boolean;

   function Parse_Sort_Key
     (Text : String;
      Key  : out Sort_Keys.Sort_Key_Definition) return Boolean;

   --  Concatenates every input operand, or standard input without operands.
   procedure Read_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Run_Options;
      Text    : out Unbounded_String;
      Ok      : out Boolean);

   procedure Write_Output
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Run_Options;
      Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Ok      : out Boolean);

   function Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Options : out Run_Options) return Boolean
   is
      Skip_Next : Boolean := False;

      function Add_Key (Text : String) return Boolean;

      function Add_Key (Text : String) return Boolean is
         Key : Sort_Keys.Sort_Key_Definition;
      begin
         if Parse_Sort_Key (Text, Key) then
            Options.Sorting.Keys.Append (Key);
            return True;
         end if;
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Text);
         return False;
      end Add_Key;
   begin
      Options := (others => <>);
      Options.Sorting.Locale :=
        To_Unbounded_String (Context.Category_Locale (Posix_Tools.Commands.Contexts.Collation));
      Options.Sorting.Numeric_Locale :=
        To_Unbounded_String (Context.Category_Locale (Posix_Tools.Commands.Contexts.Numeric));
      Result.Status := Posix_Tools.Exit_Status.Success;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg     : constant String := Context.Argument (I);
            Has_Arg : constant Boolean := I < Context.Argument_Count;
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
            elsif Arg in "-o" | "-k" | "-t" and then not Has_Arg then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, Arg);
               return False;
            elsif Arg = "-o" then
               Options.Output_Path := To_Unbounded_String (Context.Argument (I + 1));
               Skip_Next := True;
            elsif Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-o" then
               Options.Output_Path := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
            elsif Arg = "-k" then
               if not Add_Key (Context.Argument (I + 1)) then
                  return False;
               end if;
               Skip_Next := True;
            elsif Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-k" then
               if not Add_Key (Arg (Arg'First + 2 .. Arg'Last)) then
                  return False;
               end if;
            elsif Arg = "-t" then
               if Context.Argument (I + 1)'Length /= 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Context.Argument (I + 1));
                  return False;
               end if;
               Options.Sorting.Field_Separator := Context.Argument (I + 1) (Context.Argument (I + 1)'First);
               Options.Sorting.Has_Field_Separator := True;
               Skip_Next := True;
            elsif Arg'Length = 3 and then Arg (Arg'First .. Arg'First + 1) = "-t" then
               Options.Sorting.Field_Separator := Arg (Arg'Last);
               Options.Sorting.Has_Field_Separator := True;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'c' | 'C' => Options.Check_Only := True;
                     when 'b' => Options.Sorting.Global.Ignore_Leading_Blanks := True;
                     when 'd' => Options.Sorting.Global.Dictionary_Order := True;
                     when 'f' => Options.Sorting.Global.Fold_Case := True;
                     when 'i' => Options.Sorting.Global.Ignore_Nonprinting := True;
                     when 'm' => null;
                     when 'n' => Options.Sorting.Global.Numeric_Sort := True;
                     when 'r' => Options.Sorting.Global.Reverse_Order := True;
                     when 's' => Options.Sorting.Stable_Sort := True;
                     when 'u' => Options.Sorting.Unique := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unknown_Option, "-" & Ch);
                        return False;
                  end case;
               end loop;
            else
               Options.Files.Append (Arg);
            end if;
         end;
      end loop;
      return True;
   end Parse_Options;

   function Parse_Sort_Key
     (Text : String;
      Key  : out Sort_Keys.Sort_Key_Definition) return Boolean
   is
      Parsed : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key :=
        Posix_Tools.Text.Sort_Modifiers.Parse_Key (Text);
      Rules  : constant Sort_Keys.Ordering_Rules :=
        (Fold_Case             => Parsed.Fold_Case,
         Numeric_Sort          => Parsed.Numeric_Sort,
         Ignore_Leading_Blanks => Parsed.Ignore_Leading_Blanks,
         Dictionary_Order      => Parsed.Dictionary_Order,
         Ignore_Nonprinting    => Parsed.Ignore_Nonprinting,
         Reverse_Order         => Parsed.Reverse_Order);
      use type Sort_Keys.Ordering_Rules;
   begin
      Key := (others => <>);
      if not Parsed.Valid then
         return False;
      end if;

      Key :=
        (Field_Start     => Parsed.Field_Start,
         Field_End       => Parsed.Field_End,
         Character_Start => Parsed.Character_Start,
         Character_End   => Parsed.Character_End,
         Rules           => Rules,
         Has_Modifiers   => Rules /= (others => False));
      return True;
   end Parse_Sort_Key;

   procedure Read_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Run_Options;
      Text    : out Unbounded_String;
      Ok      : out Boolean) is
   begin
      Text := Null_Unbounded_String;
      Ok := True;
      if Options.Files.Is_Empty then
         Text := To_Unbounded_String (Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context));
         return;
      end if;

      for Name of Options.Files loop
         if Name = "-" then
            Append (Text, Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context));
         else
            Append (Text, Posix_Tools.Commands.File_Helpers.Read_File (Context, Name, Ok));
            exit when not Ok;
         end if;
      end loop;
   end Read_Input;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options : Run_Options;
      Text    : Unbounded_String;
      Ok      : Boolean;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      elsif not Parse_Options (Context, Result, Options) then
         return;
      end if;

      Read_Input (Context, Options, Text, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         Lines : String_Vectors.Vector := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Text));
      begin
         Text := Null_Unbounded_String;
         if Options.Check_Only then
            Result.Status :=
              (if Sort_Keys.Lines_Are_Sorted (Lines, Options.Sorting)
               then Posix_Tools.Exit_Status.Success
               else Posix_Tools.Exit_Status.Operational_Failure);
            return;
         end if;

         Sort_Keys.Sort_Lines (Lines, Options.Sorting);
         Write_Output (Context, Options, Lines, Ok);
      end;

      Result.Status :=
        (if Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

   procedure Write_Output
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Run_Options;
      Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Ok      : out Boolean)
   is
      Output : Unbounded_String;
   begin
      for Line of Lines loop
         Append (Output, Line);
         Append (Output, LF);
      end loop;

      Ok := True;
      if Length (Options.Output_Path) = 0 then
         Context.Put (To_String (Output));
      else
         Posix_Tools.Commands.File_Helpers.Write_File
           (To_String (Options.Output_Path), To_String (Output), False, Ok);
         if not Ok then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Options.Output_Path),
               "posix_tools.diagnostic.file.write_failed", "cannot write file");
         end if;
      end if;
   end Write_Output;
end Posix_Tools.Commands.Sort;
