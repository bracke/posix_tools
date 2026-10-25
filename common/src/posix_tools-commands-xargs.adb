with Ada.Containers;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Xargs_Fields;
with Posix_Tools.Text.Xargs_Parsing;

package body Posix_Tools.Commands.Xargs is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;

   type Run_Options is record
      Fixed_Args            : Posix_Tools.Arguments.Vector;
      Batch_Size            : Natural := 0;
      Null_Delimited        : Boolean := False;
      No_Run_If_Empty       : Boolean := False;
      Trace_Mode            : Boolean := False;
      Exit_If_Size_Exceeded : Boolean := False;
      Has_Eof_Marker        : Boolean := False;
      Eof_Marker            : Unbounded_String;
      Replacement_Mode      : Boolean := False;
      Replacement_String    : Unbounded_String;
      Command_Size_Limit    : Natural := 131_072;
   end record;

   --  What became of one invocation.
   type Batch_Outcome is (Batch_Ok, Batch_Failed, Batch_Stopped);

   --  The arguments of one invocation, without the utility name.
   function Compose
     (Options                 : Run_Options;
      Input_Args              : Posix_Tools.Arguments.Vector;
      First_Input, Last_Input : Natural) return Posix_Tools.Arguments.Vector;

   function Composed_Command_Size
     (Options   : Run_Options;
      Arguments : Posix_Tools.Arguments.Vector) return Natural;

   --  Parses the command line into Options; False after a usage error.
   function Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Options : out Run_Options) return Boolean;

   function Replace_All (Template, Pattern, Value : String) return String;

   function Utility_Name (Options : Run_Options) return String is
     (if Options.Fixed_Args.Length = 0 then "echo" else Options.Fixed_Args.Element (1));

   function Compose
     (Options                 : Run_Options;
      Input_Args              : Posix_Tools.Arguments.Vector;
      First_Input, Last_Input : Natural) return Posix_Tools.Arguments.Vector
   is
      Arguments : Posix_Tools.Arguments.Vector;
   begin
      if Options.Replacement_Mode then
         for I in 2 .. Natural (Options.Fixed_Args.Length) loop
            Arguments.Append
              (Replace_All
                 (Options.Fixed_Args.Element (I),
                  To_String (Options.Replacement_String),
                  (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "")));
         end loop;
      else
         for I in 2 .. Natural (Options.Fixed_Args.Length) loop
            Arguments.Append (Options.Fixed_Args.Element (I));
         end loop;
         for I in First_Input .. Last_Input loop
            Arguments.Append (Input_Args.Element (I));
         end loop;
      end if;
      return Arguments;
   end Compose;

   function Composed_Command_Size
     (Options   : Run_Options;
      Arguments : Posix_Tools.Arguments.Vector) return Natural
   is
      Total : Natural := Posix_Tools.Text.Xargs_Fields.Size_With_Item (0, Utility_Name (Options)'Length);
   begin
      for Item of Arguments loop
         Total := Posix_Tools.Text.Xargs_Fields.Size_With_Item (Total, Item'Length);
      end loop;
      return Total;
   end Composed_Command_Size;

   function Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Options : out Run_Options) return Boolean
   is
      Skip_Next          : Boolean := False;
      Parsing_Fixed_Args : Boolean := False;

      --  -n and -s: a positive count, from Text.
      function Set_Count (Option : Character; Text : String) return Boolean;

      function Set_Count (Option : Character; Text : String) return Boolean is
         Message : constant Posix_Tools.Commands.Usage_Messages.Usage_Message :=
           (if Option = 'n' then Invalid_Argument_Count else Invalid_Command_Size);
         Value   : Natural;
      begin
         if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand (Context, Result, Text, Message, Value) then
            return False;
         elsif Value = 0 then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Message, Text);
            return False;
         elsif Option = 'n' then
            Options.Batch_Size := Value;
         else
            Options.Command_Size_Limit := Value;
         end if;
         return True;
      end Set_Count;
   begin
      Options := (others => <>);
      Result.Status := Posix_Tools.Exit_Status.Success;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg     : constant String := Context.Argument (I);
            Has_Arg : constant Boolean := I < Context.Argument_Count;
         begin
            if Skip_Next then
               Skip_Next := False;
            elsif Parsing_Fixed_Args then
               Options.Fixed_Args.Append (Arg);
            elsif Arg = "--" then
               Parsing_Fixed_Args := True;
            elsif Arg = "-0" then
               Options.Null_Delimited := True;
            elsif Arg = "-r" or else Arg = "--no-run-if-empty" then
               Options.No_Run_If_Empty := True;
            elsif Arg = "-t" then
               Options.Trace_Mode := True;
            elsif Arg = "-x" then
               Options.Exit_If_Size_Exceeded := True;
            elsif Arg in "-I" | "-E" | "-n" | "-s" and then not Has_Arg then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, Arg);
               return False;
            elsif Arg = "-E" then
               Options.Has_Eof_Marker := True;
               Options.Eof_Marker := To_Unbounded_String (Context.Argument (I + 1));
               Skip_Next := True;
            elsif Arg'Length >= 2 and then Arg (Arg'First .. Arg'First + 1) = "-I" then
               Options.Replacement_Mode := True;
               Options.Replacement_String :=
                 To_Unbounded_String
                   (if Arg'Length = 2 then Context.Argument (I + 1) else Arg (Arg'First + 2 .. Arg'Last));
               Options.Batch_Size := 1;
               Skip_Next := Arg'Length = 2;
            elsif Arg'Length >= 2 and then Arg (Arg'First .. Arg'First + 1) in "-n" | "-s" then
               if not Set_Count
                 (Arg (Arg'First + 1),
                  (if Arg'Length = 2 then Context.Argument (I + 1) else Arg (Arg'First + 2 .. Arg'Last)))
               then
                  return False;
               end if;
               Skip_Next := Arg'Length = 2;
            else
               Options.Fixed_Args.Append (Arg);
               Parsing_Fixed_Args := True;
            end if;
         end;
      end loop;
      return True;
   end Parse_Options;

   function Replace_All (Template, Pattern, Value : String) return String is
      Replaced : Unbounded_String;
      I        : Positive := Template'First;
   begin
      if Pattern = "" then
         return Template;
      end if;

      while I <= Template'Last loop
         if I + Pattern'Length - 1 <= Template'Last
           and then Template (I .. I + Pattern'Length - 1) = Pattern
         then
            Append (Replaced, Value);
            I := I + Pattern'Length;
         else
            Append (Replaced, Template (I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Replaced);
   end Replace_All;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options    : Run_Options;
      Input_Args : Posix_Tools.Arguments.Vector;
      Any_Failed : Boolean := False;

      --  Runs one invocation. POSIX xargs: an invocation exiting 1 through
      --  125 does not stop xargs, which exits 1-125 at the end (123 here);
      --  one exiting 255 or killed by a signal stops it with a diagnostic, as
      --  does a utility that cannot be found (127) or invoked (126).
      function Execute_Batch (First_Input, Last_Input : Natural) return Batch_Outcome;

      procedure Stop (Status : Posix_Tools.Exit_Status.Code; Key, Default : String);

      function Execute_Batch (First_Input, Last_Input : Natural) return Batch_Outcome is
         Utility   : constant String := Utility_Name (Options);
         Arguments : constant Posix_Tools.Arguments.Vector := Compose (Options, Input_Args, First_Input, Last_Input);
         Exit_Code : Integer := 0;
      begin
         if Composed_Command_Size (Options, Arguments) > Options.Command_Size_Limit then
            Stop (Posix_Tools.Exit_Status.Operational_Failure,
                  "posix_tools.diagnostic.resource.argument_list_too_large", "argument list too long");
            return Batch_Stopped;
         end if;

         if Options.Trace_Mode then
            declare
               Line : Unbounded_String := To_Unbounded_String (Utility);
            begin
               for Item of Arguments loop
                  Append (Line, " " & Item);
               end loop;
               Context.Put_Error_Line (To_String (Line));
            end;
            if Context.Output_Failed then
               Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               return Batch_Stopped;
            end if;
         end if;

         if not Context.Execute_Utility (Utility, Arguments, Exit_Code) then
            if Exit_Code = 126 then
               Stop (Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
                     "posix_tools.diagnostic.utility.cannot_invoke", "cannot run command");
            elsif Exit_Code = 127 then
               Stop (Posix_Tools.Exit_Status.Utility_Not_Found,
                     "posix_tools.diagnostic.utility.not_found", "command not found");
            else
               Stop (Posix_Tools.Exit_Status.Internal_Failure,
                     "posix_tools.diagnostic.utility.cannot_invoke", "cannot run command");
            end if;
            return Batch_Stopped;
         end if;

         case Exit_Code is
            when 0 =>
               return Batch_Ok;
            when 1 .. 125 =>
               Any_Failed := True;
               return Batch_Failed;
            when 126 =>
               Stop (Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
                     "posix_tools.diagnostic.utility.cannot_invoke", "cannot run command");
            when 127 =>
               Stop (Posix_Tools.Exit_Status.Utility_Not_Found,
                     "posix_tools.diagnostic.utility.not_found", "command not found");
            when 255 =>
               Stop (Posix_Tools.Exit_Status.Xargs_Utility_Requested_Stop,
                     "posix_tools.diagnostic.utility.status_255", "command exited with status 255");
            when others =>
               --  128 plus the signal number: the utility was killed.
               Stop (Posix_Tools.Exit_Status.Internal_Failure,
                     "posix_tools.diagnostic.utility.signaled", "command terminated by a signal");
         end case;
         return Batch_Stopped;
      end Execute_Batch;

      procedure Stop (Status : Posix_Tools.Exit_Status.Code; Key, Default : String) is
      begin
         Posix_Tools.Commands.Helpers.Subject_Operational_Error (Context, Utility_Name (Options), Key, Default);
         Result.Status := Status;
      end Stop;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      elsif not Parse_Options (Context, Result, Options) then
         return;
      end if;

      --  Posix_Tools.Text.Xargs_Parsing owns Text.Byte_Classes.Is_Xargs_Blank
      --  based tokenization; this command maps parser statuses to diagnostics.
      declare
         Input_Ok     : Boolean;
         Input        : constant String :=
           Posix_Tools.Commands.File_Helpers.Streaming.Read_File (Context, "-", Input_Ok);
         Parsed_Input : constant Posix_Tools.Text.Xargs_Parsing.Parse_Result :=
           Posix_Tools.Text.Xargs_Parsing.Parse_Input
             (Input,
              Options.Null_Delimited,
              Options.Replacement_Mode,
              Options.Has_Eof_Marker,
              To_String (Options.Eof_Marker));
      begin
         if not Input_Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         case Parsed_Input.Status is
            when Posix_Tools.Text.Xargs_Parsing.Valid =>
               Input_Args := Parsed_Input.Items;
            when Posix_Tools.Text.Xargs_Parsing.Unmatched_Single_Quote =>
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unmatched_Single_Quote);
               return;
            when Posix_Tools.Text.Xargs_Parsing.Unmatched_Double_Quote =>
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unmatched_Double_Quote);
               return;
            when Posix_Tools.Text.Xargs_Parsing.Unfinished_Escape =>
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unfinished_Escape);
               return;
         end case;
      end;

      if Options.Batch_Size = 0 and then Input_Args.Length > 0 then
         Options.Batch_Size := Natural (Input_Args.Length);
      end if;

      if Input_Args.Length = 0 then
         if not Options.No_Run_If_Empty and then Execute_Batch (1, 0) = Batch_Stopped then
            return;
         end if;
      else
         declare
            First : Natural := 1;
            Last  : Natural;
         begin
            while First <= Natural (Input_Args.Length) loop
               Last := Natural'Min (First + Options.Batch_Size - 1, Natural (Input_Args.Length));
               if Options.Exit_If_Size_Exceeded
                 and then Composed_Command_Size (Options, Compose (Options, Input_Args, First, Last))
                   > Options.Command_Size_Limit
               then
                  Posix_Tools.Commands.Helpers.Operational_Error
                    (Context,
                     "posix_tools.diagnostic.resource.argument_list_too_large",
                     "argument list too long");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               while Last > First
                 and then Composed_Command_Size (Options, Compose (Options, Input_Args, First, Last))
                   > Options.Command_Size_Limit
               loop
                  Last := Last - 1;
               end loop;
               if Execute_Batch (First, Last) = Batch_Stopped then
                  return;
               end if;
               First := Last + 1;
            end loop;
         end;
      end if;

      Result.Status :=
        (if Any_Failed then Posix_Tools.Exit_Status.Xargs_Utility_Failed
         elsif Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Xargs;
