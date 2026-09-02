with Awklib.Interpreter;
with Awklib;
with Awk_CLI.Execution.Callbacks;

package body Awk_CLI.Execution is
   package I renames Awklib.Interpreter;
   use type I.Run_Status;
   use type I.Runtime_Operand_Kind;

   package Mapping is
      function Build_Assignments
        (Options : Awk_CLI.Options.Parsed_Options)
         return I.Assignment_Vectors.Vector;

      function Build_Environment
        (Environment : Awk_CLI.Environment.Entry_Vectors.Vector)
         return I.Assignment_Vectors.Vector;

      function Build_Auxiliary_Files
        (Inputs          : Awk_CLI.Inputs.Input_File_Vectors.Vector;
         Auxiliary_Files : Awk_CLI.Inputs.Input_File_Vectors.Vector;
         Live_Input      : Live_Input_Reader) return I.Assignment_Vectors.Vector;

      function Build_Arguments
        (Operands : Awk_CLI.Operands.Operand_Vectors.Vector)
         return I.String_Vectors.Vector;

      function Build_Runtime_Operands
        (Operands : Awk_CLI.Operands.Operand_Vectors.Vector)
         return I.Runtime_Operand_Vectors.Vector;
   end Mapping;

   package body Mapping is separate;

   package Runner is
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
         return Execution_Result;
   end Runner;

   package body Runner is separate;

   function Execute
     (Program_Source  : String;
      Options         : Awk_CLI.Options.Parsed_Options;
      Operands        : Awk_CLI.Operands.Operand_Vectors.Vector;
      Inputs          : Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Environment     : Awk_CLI.Environment.Entry_Vectors.Vector)
      return Execution_Result
   is
   begin
      return Runner.Execute_Core
        (Program_Source, Options, Operands, Inputs, Environment,
         Live_Input => null,
         Live_Output => null,
         Live_Redirection => null,
         Live_Command => null,
         Live_User_Data => System.Null_Address);
   end Execute;

   function Execute_Live
     (Program_Source  : String;
      Options         : Awk_CLI.Options.Parsed_Options;
      Operands        : Awk_CLI.Operands.Operand_Vectors.Vector;
      Inputs          : Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Environment     : Awk_CLI.Environment.Entry_Vectors.Vector;
      Write_Output    : not null Live_Output_Writer;
      Write_Redirection : not null Live_Redirection_Writer;
      Read_Command    : Live_Command_Reader := null;
      User_Data       : System.Address := System.Null_Address)
      return Execution_Result
   is
   begin
      return Runner.Execute_Core
        (Program_Source, Options, Operands, Inputs, Environment,
         Live_Input => null,
         Live_Output => Write_Output,
         Live_Redirection => Write_Redirection,
         Live_Command => Read_Command,
         Live_User_Data => User_Data);
   end Execute_Live;

   function Execute_Live_Input
     (Program_Source  : String;
      Options         : Awk_CLI.Options.Parsed_Options;
      Operands        : Awk_CLI.Operands.Operand_Vectors.Vector;
      Environment     : Awk_CLI.Environment.Entry_Vectors.Vector;
      Read_Input      : not null Live_Input_Reader;
      Write_Output    : not null Live_Output_Writer;
      Write_Redirection : not null Live_Redirection_Writer;
      Read_Command    : Live_Command_Reader := null;
      User_Data       : System.Address := System.Null_Address;
      Auxiliary_Files : Awk_CLI.Inputs.Input_File_Vectors.Vector :=
        Awk_CLI.Inputs.Input_File_Vectors.Empty_Vector)
      return Execution_Result
   is
   begin
      return Runner.Execute_Core
        (Program_Source, Options, Operands,
         Awk_CLI.Inputs.Input_File_Vectors.Empty_Vector, Environment,
         Live_Input => Read_Input,
         Live_Output => Write_Output,
         Live_Redirection => Write_Redirection,
         Live_Command => Read_Command,
         Live_User_Data => User_Data,
         Auxiliary_Files => Auxiliary_Files);
   end Execute_Live_Input;

   function Interpreter_Version return String is (Awklib.Version);
   function Supports_Positional_Runtime_Assignments return Boolean is (True);
   function Supports_Redirection_Append_Mode return Boolean is (True);
   function Supports_Streaming_Execution return Boolean is (True);
end Awk_CLI.Execution;
