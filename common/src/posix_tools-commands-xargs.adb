with Ada.Containers;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Xargs_Fields;
with Posix_Tools.Text.Xargs_Parsing;

package body Posix_Tools.Commands.Xargs is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Data        : constant String :=
        Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context);
      Fixed_Args  : Posix_Tools.Arguments.Vector;
      Input_Args  : Posix_Tools.Arguments.Vector;
      Batch_Size  : Natural := 0;
      Skip_Next   : Boolean := False;
      Null_Delimited : Boolean := False;
      No_Run_If_Empty : Boolean := False;
      Trace_Mode : Boolean := False;
      Exit_If_Size_Exceeded : Boolean := False;
      Has_Eof_Marker : Boolean := False;
      Eof_Marker : Unbounded_String;
      Replacement_Mode : Boolean := False;
      Replacement_String : Unbounded_String;
      Command_Size_Limit : Natural := 131_072;
      Parsing_Fixed_Args : Boolean := False;

      procedure Add_Command_Size (Total : in out Natural; Item : String);

      function Composed_Command_Size (First_Input, Last_Input : Natural) return Natural;

      procedure Execute_Batch (First_Input, Last_Input : Natural; Ok : out Boolean);

      function Render_Command (First_Input, Last_Input : Natural) return String;

      function Replace_All (Template, Pattern, Value : String) return String;

      procedure Add_Command_Size (Total : in out Natural; Item : String) is
      begin
         Total := Posix_Tools.Text.Xargs_Fields.Size_With_Item (Total, Item'Length);
      end Add_Command_Size;

      function Composed_Command_Size (First_Input, Last_Input : Natural) return Natural is
         Utility : constant String :=
           (if Fixed_Args.Length = 0 then "echo" else Fixed_Args.Element (1));
         Total : Natural := 0;
      begin
         Add_Command_Size (Total, Utility);

         if Replacement_Mode then
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Add_Command_Size
                 (Total,
                  Replace_All
                    (Fixed_Args.Element (I),
                     To_String (Replacement_String),
                     (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "")));
            end loop;
         else
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Add_Command_Size (Total, Fixed_Args.Element (I));
            end loop;

            for I in First_Input .. Last_Input loop
               Add_Command_Size (Total, Input_Args.Element (I));
            end loop;
         end if;

         return Total;
      end Composed_Command_Size;

      procedure Execute_Batch (First_Input, Last_Input : Natural; Ok : out Boolean) is
         Utility : constant String :=
           (if Fixed_Args.Length = 0 then "echo" else Fixed_Args.Element (1));
         Arguments : Posix_Tools.Arguments.Vector;
         Exit_Code : Integer := 0;
      begin
         Ok := True;
         if Composed_Command_Size (First_Input, Last_Input) > Command_Size_Limit then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.resource.argument_list_too_large", "argument list too long");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            Ok := False;
            return;
         end if;

         if Trace_Mode then
            Context.Put_Error_Line (Render_Command (First_Input, Last_Input));
            if Context.Output_Failed then
               Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               Ok := False;
               return;
            end if;
         end if;

         if Replacement_Mode then
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Arguments.Append
                 (Replace_All
                    (Fixed_Args.Element (I),
                     To_String (Replacement_String),
                     (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "")));
            end loop;
         else
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Arguments.Append (Fixed_Args.Element (I));
            end loop;

            for I in First_Input .. Last_Input loop
               Arguments.Append (Input_Args.Element (I));
            end loop;
         end if;

         if not Context.Execute_Utility (Utility, Arguments, Exit_Code) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Utility, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Classify_Xargs_Status (False, Exit_Code);
            Ok := False;
         elsif Exit_Code /= 0 then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Utility, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Classify_Xargs_Status (True, Exit_Code);
            Ok := False;
         end if;
      end Execute_Batch;

      function Render_Command (First_Input, Last_Input : Natural) return String is
         Utility : constant String :=
           (if Fixed_Args.Length = 0 then "echo" else Fixed_Args.Element (1));
         Line : Unbounded_String := To_Unbounded_String (Utility);

         procedure Append_Argument (Item : String);

         procedure Append_Argument (Item : String) is
         begin
            Append (Line, " ");
            Append (Line, Item);
         end Append_Argument;
      begin
         if Replacement_Mode then
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Append_Argument
                 (Replace_All
                    (Fixed_Args.Element (I),
                     To_String (Replacement_String),
                     (if First_Input <= Last_Input then Input_Args.Element (First_Input) else "")));
            end loop;
         else
            for I in 2 .. Natural (Fixed_Args.Length) loop
               Append_Argument (Fixed_Args.Element (I));
            end loop;

            for I in First_Input .. Last_Input loop
               Append_Argument (Input_Args.Element (I));
            end loop;
         end if;

         return To_String (Line);
      end Render_Command;

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
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if Skip_Next then
            Skip_Next := False;
         elsif Parsing_Fixed_Args then
            Fixed_Args.Append (Context.Argument (I));
         elsif Context.Argument (I) = "--" then
            Parsing_Fixed_Args := True;
         elsif Context.Argument (I) = "-0" then
            Null_Delimited := True;
         elsif Context.Argument (I) = "-I" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-I'");
               return;
            end if;
            Replacement_Mode := True;
            Replacement_String := To_Unbounded_String (Context.Argument (I + 1));
            Batch_Size := 1;
            Skip_Next := True;
         elsif Context.Argument (I)'Length > 2
           and then Context.Argument (I) (Context.Argument (I)'First .. Context.Argument (I)'First + 1) = "-I"
         then
            Replacement_Mode := True;
            Replacement_String :=
              To_Unbounded_String
                (Context.Argument (I) (Context.Argument (I)'First + 2 .. Context.Argument (I)'Last));
            Batch_Size := 1;
         elsif Context.Argument (I) = "-r" or else Context.Argument (I) = "--no-run-if-empty" then
            No_Run_If_Empty := True;
         elsif Context.Argument (I) = "-t" then
            Trace_Mode := True;
         elsif Context.Argument (I) = "-x" then
            Exit_If_Size_Exceeded := True;
         elsif Context.Argument (I) = "-E" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-E'");
               return;
            end if;
            Has_Eof_Marker := True;
            Eof_Marker := To_Unbounded_String (Context.Argument (I + 1));
            Skip_Next := True;
         elsif Context.Argument (I) = "-n" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-n'");
               return;
            end if;
            if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
              (Context, Result, Context.Argument (I + 1), "argument count", Batch_Size)
            then
               return;
            elsif Batch_Size = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid argument count '0'");
               return;
            end if;
            Skip_Next := True;
         elsif Context.Argument (I)'Length > 2
           and then Context.Argument (I) (Context.Argument (I)'First .. Context.Argument (I)'First + 1) = "-n"
         then
            if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
              (Context,
               Result,
               Context.Argument (I) (Context.Argument (I)'First + 2 .. Context.Argument (I)'Last),
               "argument count",
               Batch_Size)
            then
               return;
            elsif Batch_Size = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid argument count '0'");
               return;
            end if;
         elsif Context.Argument (I) = "-s" then
            if I = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-s'");
               return;
            end if;
            if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
              (Context, Result, Context.Argument (I + 1), "command size", Command_Size_Limit)
            then
               return;
            elsif Command_Size_Limit = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid command size '0'");
               return;
            end if;
            Skip_Next := True;
         elsif Context.Argument (I)'Length > 2
           and then Context.Argument (I) (Context.Argument (I)'First .. Context.Argument (I)'First + 1) = "-s"
         then
            if not Posix_Tools.Commands.Helpers.Parse_Natural_Operand
              (Context,
               Result,
               Context.Argument (I) (Context.Argument (I)'First + 2 .. Context.Argument (I)'Last),
               "command size",
               Command_Size_Limit)
            then
               return;
            elsif Command_Size_Limit = 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid command size '0'");
               return;
            end if;
         else
            Fixed_Args.Append (Context.Argument (I));
            Parsing_Fixed_Args := True;
         end if;
      end loop;

      --  Posix_Tools.Text.Xargs_Parsing owns Text.Byte_Classes.Is_Xargs_Blank
      --  based tokenization; this command maps parser statuses to diagnostics.
      declare
         Parsed_Input : constant Posix_Tools.Text.Xargs_Parsing.Parse_Result :=
           Posix_Tools.Text.Xargs_Parsing.Parse_Input
             (Data,
              Null_Delimited,
              Replacement_Mode,
              Has_Eof_Marker,
              To_String (Eof_Marker));
      begin
         case Parsed_Input.Status is
            when Posix_Tools.Text.Xargs_Parsing.Valid =>
               Input_Args := Parsed_Input.Items;
            when Posix_Tools.Text.Xargs_Parsing.Unmatched_Single_Quote =>
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unmatched single quote");
               return;
            when Posix_Tools.Text.Xargs_Parsing.Unmatched_Double_Quote =>
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unmatched double quote");
               return;
            when Posix_Tools.Text.Xargs_Parsing.Unfinished_Escape =>
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unfinished escape");
               return;
         end case;
      end;

      if Batch_Size = 0 and then Input_Args.Length > 0 then
         Batch_Size := Natural (Input_Args.Length);
      end if;

      if Input_Args.Length = 0 then
         if No_Run_If_Empty then
            Result.Status :=
              (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
               else Posix_Tools.Exit_Status.Success);
            return;
         else
            declare
               Exec_Ok : Boolean;
            begin
               Execute_Batch (1, 0, Exec_Ok);
               if not Exec_Ok then
                  return;
               end if;
            end;
         end if;
      else
         declare
            First : Natural := 1;
            Last  : Natural;
            Exec_Ok : Boolean;
         begin
            while First <= Natural (Input_Args.Length) loop
               Last := Natural'Min (First + Batch_Size - 1, Natural (Input_Args.Length));
               if Exit_If_Size_Exceeded and then Composed_Command_Size (First, Last) > Command_Size_Limit then
                  Posix_Tools.Commands.Helpers.Operational_Error
                    (Context,
                     "posix_tools.diagnostic.resource.argument_list_too_large",
                     "argument list too long");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               while Last > First and then Composed_Command_Size (First, Last) > Command_Size_Limit loop
                  Last := Last - 1;
               end loop;
               Execute_Batch (First, Last, Exec_Ok);
               if not Exec_Ok then
                  return;
               end if;
               First := Last + 1;
            end loop;
         end;
      end if;

      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Xargs;
