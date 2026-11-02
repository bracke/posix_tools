with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Sort_Keys;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Sort_Modifiers;

package body Posix_Tools.Commands.Sort is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;
   package Sort_Keys renames Posix_Tools.Commands.Sort_Keys;

   --  Sort the input, or check that it is sorted: -c says where it is not,
   --  -C only exits 1.
   type Check_Mode is (Sort_Input, Diagnose_Disorder, Quiet);

   type Run_Options is record
      Files       : String_Vectors.Vector;
      Output_Path : Unbounded_String;
      Check       : Check_Mode := Sort_Input;
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

   --  Concatenates every input operand, or standard input without operands,
   --  ending each that lacks one with a newline.
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
      First : Positive;
      Valid : Boolean;

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
         Key : Sort_Keys.Sort_Key_Definition;
      begin
         Valid := True;
         case Name is
            when 'c' => Options.Check := Diagnose_Disorder;
            when 'C' => Options.Check := Quiet;
            when 'b' => Options.Sorting.Global.Ignore_Leading_Blanks := True;
            when 'd' => Options.Sorting.Global.Dictionary_Order := True;
            when 'f' => Options.Sorting.Global.Fold_Case := True;
            when 'i' => Options.Sorting.Global.Ignore_Nonprinting := True;
            when 'm' => null;
            when 'n' => Options.Sorting.Global.Numeric_Sort := True;
            when 'r' => Options.Sorting.Global.Reverse_Order := True;
            when 's' => Options.Sorting.Stable_Sort := True;
            when 'u' => Options.Sorting.Unique := True;
            when 'o' => Options.Output_Path := To_Unbounded_String (Value);
            when 'k' =>
               if Parse_Sort_Key (Value, Key) then
                  Options.Sorting.Keys.Append (Key);
               else
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
            when 't' =>
               if Value'Length /= 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               else
                  Options.Sorting.Field_Separator := Value (Value'First);
                  Options.Sorting.Has_Field_Separator := True;
               end if;
            when others =>
               null;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      Options := (others => <>);
      Options.Sorting.Locale :=
        To_Unbounded_String (Context.Category_Locale (Posix_Tools.Commands.Contexts.Collation));
      Options.Sorting.Numeric_Locale :=
        To_Unbounded_String (Context.Category_Locale (Posix_Tools.Commands.Contexts.Numeric));
      Result.Status := Posix_Tools.Exit_Status.Success;

      Parse (Context, Result, "bcCdfikmnorstu", "kot", First, Valid);
      if not Valid then
         return False;
      end if;
      for I in First .. Context.Argument_Count loop
         Options.Files.Append (Context.Argument (I));
      end loop;
      --  -c and -C check one input.
      if Options.Check /= Sort_Input and then Natural (Options.Files.Length) > 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Options.Files.Element (2));
         return False;
      end if;
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
         Text := To_Unbounded_String (Posix_Tools.Commands.File_Helpers.Streaming.Read_File (Context, "-", Ok));
         return;
      end if;

      for Name of Options.Files loop
         declare
            Data : constant String := Posix_Tools.Commands.File_Helpers.Streaming.Read_File (Context, Name, Ok);
         begin
            exit when not Ok;
            Append (Text, Data);
            if Data'Length > 0 and then Data (Data'Last) /= LF then
               Append (Text, LF);
            end if;
         end;
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
         if Options.Check /= Sort_Input then
            declare
               Disorder : constant Natural := Sort_Keys.First_Disorder (Lines, Options.Sorting);
            begin
               if Disorder = 0 then
                  Result.Status := Posix_Tools.Exit_Status.Success;
               else
                  if Options.Check = Diagnose_Disorder then
                     Posix_Tools.Commands.Helpers.Operational_Error
                       (Context, "posix_tools.diagnostic.sort.disorder", "line",
                        Lines.Element (Disorder), "disorder: '{line}'");
                  end if;
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               end if;
            end;
            return;
         end if;

         Sort_Keys.Sort_Lines (Lines, Options.Sorting);
         Write_Output (Context, Options, Lines, Ok);
      end;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
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
         Posix_Tools.Host_Adapters.File_System.Write_File
           (To_String (Options.Output_Path), To_String (Output), False, Ok);
         if not Ok then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Options.Output_Path),
               "posix_tools.diagnostic.file.write_failed", "cannot write file");
         end if;
      end if;
   end Write_Output;
end Posix_Tools.Commands.Sort;
