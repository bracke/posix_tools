with Ada.Exceptions;

separate (Awk_CLI.Execution)
package body Runner is
   function Build_Run_Result
     (Status    : I.Run_Status;
      Message   : U.Unbounded_String;
      State     : Awk_CLI.Execution.Callbacks.Stream_State;
      Output    : U.Unbounded_String;
      Exit_Code : Integer;
      Redirs    : Awk_CLI.Redirections.Redirection_Vectors.Vector)
      return Execution_Result
   is
   begin
      if Status = I.Run_Error then
         return
           (Ok => False,
            Diagnostic =>
              Awk_CLI.Diagnostics.Make
                ("awk.interpreter.runtime_failed",
                 Awk_CLI.Diagnostics.Error,
                 Awk_CLI.Diagnostics.Interpreter,
                 Detail => U.To_String (Message)));
      elsif Awk_CLI.Execution.Callbacks.Failed (State) then
         return (Ok => False, Diagnostic => Awk_CLI.Execution.Callbacks.Failure (State));
      else
         return
           (Ok => True, Standard_Output => Output, Exit_Status => Exit_Code,
            Redirections => Redirs);
      end if;
   end Build_Run_Result;

   function Execute_Core
     (Program_Source  : String;
      Options         : Awk_CLI.Options.Parsed_Options;
      Operands        : Awk_CLI.Operands.Operand_Vectors.Vector;
      Inputs          : Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Environment     : Awk_CLI.Environment.Entry_Vectors.Vector;
      Live_Input      : Live_Input_Reader;
      Live_Output     : Live_Output_Writer;
      Live_Redirection : Live_Redirection_Writer;
      Live_Command    : Live_Command_Reader;
      Live_User_Data  : System.Address;
      Auxiliary_Files : Awk_CLI.Inputs.Input_File_Vectors.Vector :=
        Awk_CLI.Inputs.Input_File_Vectors.Empty_Vector)
      return Execution_Result
   is
      Assignments  : constant I.Assignment_Vectors.Vector :=
        Mapping.Build_Assignments (Options);
      Env          : constant I.Assignment_Vectors.Vector :=
        Mapping.Build_Environment (Environment);
      Aux_Files    : constant I.Assignment_Vectors.Vector :=
        Mapping.Build_Auxiliary_Files (Inputs, Auxiliary_Files, Live_Input);
      Arguments    : constant I.String_Vectors.Vector :=
        Mapping.Build_Arguments (Operands);
      Runtime_Operands : I.Runtime_Operand_Vectors.Vector;
      Output       : aliased U.Unbounded_String;
      Message      : U.Unbounded_String;
      Redirs       : aliased Awk_CLI.Redirections.Redirection_Vectors.Vector;
      Exit_Code    : Integer := 0;
      Status       : I.Run_Status;
      State        : aliased Awk_CLI.Execution.Callbacks.Stream_State;
   begin
      --  Callback lifetime invariant: Inputs, Output, Redirs, and State are
      --  stack objects that remain alive until the synchronous awklib call
      --  below returns; callback addresses must not escape that call.
      Awk_CLI.Execution.Callbacks.Initialize
        (State            => State,
         Inputs           => Inputs'Unchecked_Access,
         Output           => Output'Unchecked_Access,
         Redirs           => Redirs'Unchecked_Access,
         Live_Input       => Live_Input,
         Live_Output      => Live_Output,
         Live_Redirection => Live_Redirection,
         Live_Command     => Live_Command,
         Live_User_Data   => Live_User_Data);

      if Live_Input = null then
         I.Run_Text_Streaming
           (Program_Source => Program_Source,
            Assignments    => Assignments,
            Environment    => Env,
            Initial_Filename => "",
            Read_Text      => Awk_CLI.Execution.Callbacks.Read_Text'Access,
            Write_Output   => Awk_CLI.Execution.Callbacks.Write_Output'Access,
            Write_Redirection => Awk_CLI.Execution.Callbacks.Write_Redirection'Access,
            User_Data      => State'Address,
            Exit_Code      => Exit_Code,
            Status         => Status,
            Message        => Message,
            Files          => Aux_Files,
            Arguments      => Arguments,
            Read_Command   => Awk_CLI.Execution.Callbacks.Read_Command'Access);
      else
         Runtime_Operands := Mapping.Build_Runtime_Operands (Operands);

         I.Run_Text_Streaming_With_Operands
           (Program_Source => Program_Source,
            Assignments    => Assignments,
            Environment    => Env,
            Initial_Filename => "",
            Operands       => Runtime_Operands,
            Read_Text      => Awk_CLI.Execution.Callbacks.Read_Operand_Text'Access,
            Write_Output   => Awk_CLI.Execution.Callbacks.Write_Output'Access,
            Write_Redirection => Awk_CLI.Execution.Callbacks.Write_Redirection'Access,
            User_Data      => State'Address,
            Exit_Code      => Exit_Code,
            Status         => Status,
            Message        => Message,
            Files          => Aux_Files,
            Read_Command   => Awk_CLI.Execution.Callbacks.Read_Command'Access);
      end if;

      return Build_Run_Result (Status, Message, State, Output, Exit_Code, Redirs);
   exception
      when Error : others =>
         return
           (Ok => False,
            Diagnostic =>
              Awk_CLI.Diagnostics.Make
                ("awk.internal.unexpected_exception",
                 Awk_CLI.Diagnostics.Internal_Error,
                 Awk_CLI.Diagnostics.Internal,
                 Detail => Ada.Exceptions.Exception_Name (Error)));
   end Execute_Core;
end Runner;
