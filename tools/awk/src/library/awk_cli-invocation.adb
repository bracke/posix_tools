with Ada.Strings.Unbounded;

with Awk_CLI.Context_IO;
with Awk_CLI.Execution;
with Awk_CLI.Inputs;
with Awk_CLI.Inputs.Live;
with Awk_CLI.Operands;
with Awk_CLI.Platform;
with Awk_CLI.Programs;

package body Awk_CLI.Invocation is
   package D renames Awk_CLI.Diagnostics;
   package U renames Ada.Strings.Unbounded;

   function Execute
     (Context : in out Invocation_Context;
      Options : Awk_CLI.Options.Parsed_Options) return Invocation_Result
   is
      function Read_Context_File
        (Path    : String;
         Content : out U.Unbounded_String) return Awk_CLI.Platform.Read_Status
      is (Awk_CLI.Context_IO.Read_File (Context, Path, Content));

      Source_Result : constant Awk_CLI.Programs.Resolve_Result :=
        Awk_CLI.Programs.Resolve (Options, Read_Context_File'Access);
   begin
      if not Source_Result.Ok then
         return (Ok => False, Diagnostic => Source_Result.Diagnostic);
      end if;

      declare
         Classified : aliased constant Awk_CLI.Operands.Operand_Vectors.Vector :=
           Awk_CLI.Operands.Classify (Source_Result.Source.Operands);
         Input_State : aliased Awk_CLI.Inputs.Live.Live_Input_State;
      begin
         Awk_CLI.Inputs.Live.Initialize (Input_State, Context, Classified);

         declare
            Exec_Result : constant Awk_CLI.Execution.Execution_Result :=
              Awk_CLI.Execution.Execute_Live_Input
                (U.To_String (Source_Result.Source.Text),
                 Options,
                 Classified,
                 Awk_CLI.Context_IO.Current_Environment (Context),
                 Awk_CLI.Inputs.Live.Read'Access,
                 Awk_CLI.Inputs.Live.Write_Output'Access,
                 Awk_CLI.Inputs.Live.Write_Redirection'Access,
                 Read_Command => Awk_CLI.Inputs.Live.Read_Command'Access,
                 User_Data => Input_State'Address,
                 Auxiliary_Files => Awk_CLI.Inputs.Live.Auxiliary_Files (Context));
         begin
            Awk_CLI.Inputs.Live.Close (Input_State);

            if not Exec_Result.Ok then
               return (Ok => False, Diagnostic => Exec_Result.Diagnostic);
            elsif Exec_Result.Exit_Status < 0 or else Exec_Result.Exit_Status > 255 then
               return (Ok => True, Exit_Status => Exit_Code (D.Interpreter_Exit));
            else
               return (Ok => True, Exit_Status => Exit_Code (Exec_Result.Exit_Status));
            end if;
         exception
            when others =>
               Awk_CLI.Inputs.Live.Close (Input_State);
               raise;
         end;
      end;
   end Execute;
end Awk_CLI.Invocation;
