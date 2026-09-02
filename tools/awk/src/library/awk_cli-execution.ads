with Ada.Strings.Unbounded;
with System;
with Awk_CLI.Diagnostics;
with Awk_CLI.Environment;
with Awk_CLI.Inputs;
with Awk_CLI.Operands;
with Awk_CLI.Options;
with Awk_CLI.Platform;
with Awk_CLI.Redirections;

package Awk_CLI.Execution is
   --  Sole adapter between the CLI and awklib interpreter APIs.
   --
   --  No awklib-specific type is exposed by this spec. Callers pass CLI-owned
   --  structures and receive CLI-owned execution results.

   package U renames Ada.Strings.Unbounded;

   type Execution_Result (Ok : Boolean := False) is record
      case Ok is
         when True =>
            Standard_Output : U.Unbounded_String;
            Exit_Status     : Integer := 0;
            Redirections    : Awk_CLI.Redirections.Redirection_Vectors.Vector;
         when False =>
            Diagnostic : Awk_CLI.Diagnostics.Diagnostic;
      end case;
   end record;

   type Live_Output_Writer is access function
     (User_Data : System.Address;
      Content   : String) return Boolean;

   type Live_Redirection_Writer is access function
     (User_Data : System.Address;
      Path      : String;
      Content   : String;
      Append    : Boolean) return Awk_CLI.Redirections.Write_Status;

   type Live_Input_Reader is access function
     (User_Data    : System.Address;
      Operand_Index : Positive;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status;

   type Live_Command_Reader is access function
     (User_Data : System.Address;
      Command   : String;
      Output    : out U.Unbounded_String) return Boolean;

   --  @param Program_Source Complete AWK program source.
   --  @param Options Parsed command-line options.
   --  @param Operands Classified runtime operands.
   --  @param Inputs Memory-backed input files.
   --  @param Environment Normalized environment entries.
   --  @return Execution result from awklib.
   function Execute
     (Program_Source  : String;
      Options         : Awk_CLI.Options.Parsed_Options;
      Operands        : Awk_CLI.Operands.Operand_Vectors.Vector;
      Inputs          : Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Environment     : Awk_CLI.Environment.Entry_Vectors.Vector)
      return Execution_Result;

   --  @param Program_Source Complete AWK program source.
   --  @param Options Parsed command-line options.
   --  @param Operands Classified runtime operands.
   --  @param Inputs Memory-backed input files.
   --  @param Environment Normalized environment entries.
   --  @param Write_Output Live standard-output writer callback.
   --  @param Write_Redirection Live redirected-output writer callback.
   --  @param Read_Command Optional command getline callback.
   --  @param User_Data Opaque callback state.
   --  @return Execution result from awklib.
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
      return Execution_Result;

   --  @param Program_Source Complete AWK program source.
   --  @param Options Parsed command-line options.
   --  @param Operands Classified runtime operands.
   --  @param Environment Normalized environment entries.
   --  @param Read_Input Live main-input reader callback.
   --  @param Write_Output Live standard-output writer callback.
   --  @param Write_Redirection Live redirected-output writer callback.
   --  @param Read_Command Optional command getline callback.
   --  @param User_Data Opaque callback state.
   --  @param Auxiliary_Files Memory-backed auxiliary files.
   --  @return Execution result from awklib.
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
      return Execution_Result;

   --  @return True when positional runtime assignments are supported.
   function Supports_Positional_Runtime_Assignments return Boolean;

   --  @return True when append redirection intent is exposed.
   function Supports_Redirection_Append_Mode return Boolean;

   --  @return True when streaming execution callbacks are used.
   function Supports_Streaming_Execution return Boolean;

   --  @return Resolved or built-against awklib version string.
   function Interpreter_Version return String;
end Awk_CLI.Execution;
