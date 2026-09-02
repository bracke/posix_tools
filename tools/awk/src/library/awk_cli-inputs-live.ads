with System;

with Awk_CLI.Operands;
with Awk_CLI.Platform;
with Awk_CLI.Redirections;

package Awk_CLI.Inputs.Live is
   --  Live host callback state for the awklib execution adapter.
   --
   --  This package owns input selection and callback state. AWK record, field,
   --  getline, and redirection semantics remain in awklib.

   type Live_Input_State is limited private;

   --  @param State Live callback state to initialize.
   --  @param Context Invocation context used by callbacks.
   --  @param Operands Classified operands exposed to awklib.
   procedure Initialize
     (State    : out Live_Input_State;
      Context  : in out Invocation_Context;
      Operands : aliased Awk_CLI.Operands.Operand_Vectors.Vector);

   --  @param State Live callback state to close.
   procedure Close (State : in out Live_Input_State);

   --  @param Context Invocation context containing virtual auxiliary files.
   --  @return Auxiliary files available to awklib.
   function Auxiliary_Files
     (Context : Invocation_Context) return Input_File_Vectors.Vector;

   --  @param User_Data Address of Live_Input_State.
   --  @param Operand_Index Runtime operand index requested by awklib.
   --  @param Filename Current AWK-visible filename.
   --  @param Text Chunk read for this call.
   --  @param End_Of_Input Whether this input operand is at EOF.
   --  @return Host read status for this callback.
   function Read
     (User_Data    : System.Address;
      Operand_Index : Positive;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status;

   --  @param User_Data Address of Live_Input_State.
   --  @param Content Exact AWK standard output chunk.
   --  @return True when output was accepted.
   function Write_Output
     (User_Data : System.Address;
      Content   : String) return Boolean;

   --  @param User_Data Address of Live_Input_State.
   --  @param Path AWK redirection target path.
   --  @param Content Exact redirected output chunk.
   --  @param Append Whether append semantics are requested.
   --  @return Host redirection write status.
   function Write_Redirection
     (User_Data : System.Address;
      Path      : String;
      Content   : String;
      Append    : Boolean) return Awk_CLI.Redirections.Write_Status;

   --  @param User_Data Address of Live_Input_State.
   --  @param Command Host command text requested by awklib.
   --  @param Output Captured command output.
   --  @return True when command output is available.
   function Read_Command
     (User_Data : System.Address;
      Command   : String;
      Output    : out U.Unbounded_String) return Boolean;

private
   type Context_Access is access all Invocation_Context;
   type Operand_Vector_Access is access constant Awk_CLI.Operands.Operand_Vectors.Vector;

   type Live_Input_State is limited record
      Context             : Context_Access;
      Operands            : Operand_Vector_Access;
      Operand_Index       : Natural := 0;
      Implicit_Stdin_Used : Boolean := False;
      Active              : Boolean := False;
      Active_Process      : Boolean := False;
      Active_Name         : U.Unbounded_String;
      Active_Content      : U.Unbounded_String;
      Active_Position     : Natural := 1;
      Process_Stream      : Awk_CLI.Platform.Input_Stream;
   end record;
end Awk_CLI.Inputs.Live;
