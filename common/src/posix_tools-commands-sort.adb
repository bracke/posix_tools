with Ada.Containers.Vectors;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Spill_Diagnostics;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Sort_Keys;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Output_Files;
with Posix_Tools.Host_Adapters.Temporary_Storage;
with Posix_Tools.Numbers;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Sort_Modifiers;

package body Posix_Tools.Commands.Sort is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);
   Output_Chunk_Size : constant := 64 * 1024;

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
      Options.Sorting.ASCII_Numeric_Format :=
        Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale
          (To_String (Options.Sorting.Numeric_Locale));
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

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result) is separate;

   procedure Write_Output
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Run_Options;
      Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Ok      : out Boolean)
   is
      Output : Unbounded_String;
      File   : Posix_Tools.Host_Adapters.Output_Files.Output_File;
      To_File : constant Boolean := Length (Options.Output_Path) > 0;

      procedure Flush;
      procedure Write_Direct (Text : String);

      procedure Write_Direct (Text : String) is
      begin
         if not Ok then
            return;
         elsif To_File then
            Posix_Tools.Host_Adapters.Output_Files.Write (File, Text, Ok);
         else
            Context.Put (Text);
            Ok := not Context.Output_Failed;
         end if;
      end Write_Direct;

      procedure Flush is
      begin
         if Length (Output) = 0 or else not Ok then
            return;
         else
            Write_Direct (To_String (Output));
         end if;
         Output := Null_Unbounded_String;
      end Flush;
   begin
      Ok := True;
      if To_File then
         Posix_Tools.Host_Adapters.Output_Files.Open
           (File, To_String (Options.Output_Path), False, Ok);
      end if;
      for Line of Lines loop
         if Line'Length >= 64 * 1024 then
            Flush;
            Write_Direct (Line);
            Write_Direct ([1 => LF]);
         else
            Append (Output, Line);
            Append (Output, LF);
            if Length (Output) >= 64 * 1024 then
               Flush;
            end if;
         end if;
         exit when not Ok;
      end loop;
      Flush;
      if To_File and then Posix_Tools.Host_Adapters.Output_Files.Is_Open (File) then
         declare
            Closed : Boolean;
         begin
            Posix_Tools.Host_Adapters.Output_Files.Close (File, Closed);
            Ok := Ok and Closed;
         end;
      end if;
      if not Ok then
         if To_File then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Options.Output_Path),
               "posix_tools.diagnostic.file.write_failed", "cannot write file");
         end if;
      end if;
   end Write_Output;
end Posix_Tools.Commands.Sort;
