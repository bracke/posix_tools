with Ada.Containers;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Text.Xargs_Fields;
with Posix_Tools.Text.Xargs_Parsing;

package body Posix_Tools.Commands.Xargs is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Ada.Streams.Stream_Element_Offset;
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
         declare
            Pattern : constant String := To_String (Options.Replacement_String);
            Value   : constant String :=
              (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "");
         begin
            for I in 2 .. Natural (Options.Fixed_Args.Length) loop
               Arguments.Append
                 (Replace_All (Options.Fixed_Args.Element (I), Pattern, Value));
            end loop;
         end;
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
      First : Positive;
      Valid : Boolean;

      --  -n and -s: a positive count, from Text.
      function Set_Count
        (Result : in out Posix_Tools.Commands.Results.Result;
         Option : Character;
         Text   : String) return Boolean;

      function Set_Count
        (Result : in out Posix_Tools.Commands.Results.Result;
         Option : Character;
         Text   : String) return Boolean
      is
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
            when '0' => Options.Null_Delimited := True;
            when 'r' => Options.No_Run_If_Empty := True;
            when 't' => Options.Trace_Mode := True;
            when 'x' => Options.Exit_If_Size_Exceeded := True;
            when 'E' =>
               Options.Has_Eof_Marker := True;
               Options.Eof_Marker := To_Unbounded_String (Value);
            when 'I' =>
               Options.Replacement_Mode := True;
               Options.Replacement_String := To_Unbounded_String (Value);
               Options.Batch_Size := 1;
            when others =>
               Valid := Set_Count (Result, Name, Value);
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options
        (Handle, Long_Options => "--no-run-if-empty", Long_Name => 'r');
   begin
      Options := (others => <>);
      Result.Status := Posix_Tools.Exit_Status.Success;

      Parse (Context, Result, "0rtxEIns", "EIns", First, Valid);
      if not Valid then
         return False;
      end if;

      for I in First .. Context.Argument_Count loop
         Options.Fixed_Args.Append (Context.Argument (I));
      end loop;
      return True;
   end Parse_Options;

   function Replace_All (Template, Pattern, Value : String) return String is
      Replaced : Unbounded_String;
      First    : Positive := Template'First;
      Match    : Natural;
   begin
      if Pattern = "" then
         return Template;
      end if;

      Match := Ada.Strings.Fixed.Index (Template, Pattern);
      if Match = 0 then
         return Template;
      end if;

      while Match /= 0 loop
         if First < Match then
            Append (Replaced, Template (First .. Match - 1));
         end if;
         Append (Replaced, Value);
         First := Match + Pattern'Length;
         Match :=
           (if First <= Template'Last
            then Ada.Strings.Fixed.Index (Template (First .. Template'Last), Pattern)
            else 0);
      end loop;
      if First <= Template'Last then
         Append (Replaced, Template (First .. Template'Last));
      end if;

      return To_String (Replaced);
   end Replace_All;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options    : Run_Options;
      Input_Args : Posix_Tools.Arguments.Vector;
      Any_Failed : Boolean := False;
      Stopped    : Boolean := False;
      Saw_Input  : Boolean := False;
      Current_Size : Natural := 0;
      Parser     : Posix_Tools.Text.Xargs_Parsing.Parser;

      --  Runs one invocation. POSIX xargs: an invocation exiting 1 through
      --  125 does not stop xargs, which exits 1-125 at the end (123 here);
      --  one exiting 255 or killed by a signal stops it with a diagnostic, as
      --  does a utility that cannot be found (127) or invoked (126).
      function Execute_Batch (First_Input, Last_Input : Natural) return Batch_Outcome;

      procedure Stop (Status : Posix_Tools.Exit_Status.Code; Key, Default : String);

      procedure Accept_Item (Item : String);
      procedure Flush_Batch;

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

      procedure Flush_Batch is
      begin
         if Input_Args.Is_Empty or else Stopped then
            return;
         end if;
         Stopped := Execute_Batch (1, Natural (Input_Args.Length)) = Batch_Stopped;
         Input_Args.Clear;
         Current_Size :=
           Composed_Command_Size (Options, Compose (Options, Input_Args, 1, 0));
      end Flush_Batch;

      procedure Accept_Item (Item : String) is
         Limit : constant Natural :=
           (if Options.Batch_Size = 0 then Natural'Last else Options.Batch_Size);
         Candidate : Natural;
      begin
         Saw_Input := True;
         if Options.Replacement_Mode then
            Input_Args.Clear;
            Input_Args.Append (Item);
            Current_Size :=
              Composed_Command_Size (Options, Compose (Options, Input_Args, 1, 1));
            Flush_Batch;
            return;
         end if;

         Candidate := Posix_Tools.Text.Xargs_Fields.Size_With_Item
           (Current_Size, Item'Length);
         if not Input_Args.Is_Empty
           and then (Natural (Input_Args.Length) >= Limit
                     or else Candidate > Options.Command_Size_Limit)
         then
            if Options.Exit_If_Size_Exceeded and then Candidate > Options.Command_Size_Limit then
               Stop (Posix_Tools.Exit_Status.Operational_Failure,
                     "posix_tools.diagnostic.resource.argument_list_too_large",
                     "argument list too long");
               Stopped := True;
               return;
            end if;
            Flush_Batch;
            Candidate := Posix_Tools.Text.Xargs_Fields.Size_With_Item
              (Current_Size, Item'Length);
         end if;
         if Stopped then
            return;
         elsif Candidate > Options.Command_Size_Limit then
            Stop (Posix_Tools.Exit_Status.Operational_Failure,
                  "posix_tools.diagnostic.resource.argument_list_too_large",
                  "argument list too long");
            Stopped := True;
            return;
         end if;

         Input_Args.Append (Item);
         Current_Size := Candidate;
         if Natural (Input_Args.Length) >= Limit then
            Flush_Batch;
         end if;
      end Accept_Item;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      elsif not Parse_Options (Context, Result, Options) then
         return;
      end if;

      Current_Size := Composed_Command_Size
        (Options, Compose (Options, Input_Args, 1, 0));
      Posix_Tools.Text.Xargs_Parsing.Initialize
        (Parser, Options.Null_Delimited, Options.Replacement_Mode,
         Options.Has_Eof_Marker, To_String (Options.Eof_Marker));

      declare
         Input_Ok : Boolean;

         procedure Parse_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         function Stop_Reading return Boolean is
           (Stopped or else Posix_Tools.Text.Xargs_Parsing.Is_Stopped (Parser));

         procedure Parse_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Ignored);
            Parsed : Posix_Tools.Text.Xargs_Parsing.Parse_Result;
         begin
            if Last < Buffer'First then
               return;
            end if;
            Posix_Tools.Text.Xargs_Parsing.Feed
              (Parser, Posix_Tools.Streams.Bytes.To_String (Buffer, Last), Parsed);
            for Item of Parsed.Items loop
               Accept_Item (Item);
               exit when Stopped;
            end loop;
         end Parse_Chunk;

         procedure Read_Bounded_Input is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
             (Action => Parse_Chunk);
         procedure Read_Bulk_Input is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
             (Action        => Parse_Chunk,
              Buffer_Length =>
                Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
      begin
         if Options.Has_Eof_Marker then
            Read_Bounded_Input
              (Context, "-", Input_Ok, Stop_Reading'Access);
         else
            Read_Bulk_Input
              (Context, "-", Input_Ok, Stop_Reading'Access);
         end if;
         if not Input_Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;
      end;

      if not Stopped then
         declare
            Parsed : Posix_Tools.Text.Xargs_Parsing.Parse_Result;
         begin
            Posix_Tools.Text.Xargs_Parsing.Finish (Parser, Parsed);
            case Parsed.Status is
               when Posix_Tools.Text.Xargs_Parsing.Valid =>
                  for Item of Parsed.Items loop
                     Accept_Item (Item);
                     exit when Stopped;
                  end loop;
               when Posix_Tools.Text.Xargs_Parsing.Unmatched_Single_Quote =>
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, Unmatched_Single_Quote);
                  return;
               when Posix_Tools.Text.Xargs_Parsing.Unmatched_Double_Quote =>
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, Unmatched_Double_Quote);
                  return;
               when Posix_Tools.Text.Xargs_Parsing.Unfinished_Escape =>
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, Unfinished_Escape);
                  return;
            end case;
         end;
      end if;

      if Stopped then
         return;
      end if;
      Flush_Batch;
      if Stopped then
         return;
      elsif not Saw_Input and then not Options.No_Run_If_Empty
        and then Execute_Batch (1, 0) = Batch_Stopped
      then
         return;
      end if;

      Result.Status :=
        (if Any_Failed then Posix_Tools.Exit_Status.Xargs_Utility_Failed
         elsif Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Xargs;
