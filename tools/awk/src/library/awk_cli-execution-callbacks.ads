with Ada.Strings.Unbounded;
with System;

with Awk_CLI.Diagnostics;
with Awk_CLI.Inputs;
with Awk_CLI.Redirections;

private package Awk_CLI.Execution.Callbacks is
   --  Callback state used by the synchronous awklib execution call.
   --
   --  This child package deliberately contains no awklib dependency. The
   --  parent execution adapter owns the interpreter-specific callback wiring.

   package U renames Ada.Strings.Unbounded;

   type Stream_State is limited private;

   --  @param State Callback state to initialize.
   --  @param Inputs Memory-backed main inputs.
   --  @param Output Captured standard-output buffer.
   --  @param Redirs Captured redirected-output operations.
   --  @param Live_Input Optional live input callback.
   --  @param Live_Output Optional live standard-output callback.
   --  @param Live_Redirection Optional live redirection callback.
   --  @param Live_Command Optional live command-output callback.
   --  @param Live_User_Data Opaque state for live callbacks.
   procedure Initialize
     (State            : out Stream_State;
      Inputs           : not null access constant Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Output           : not null access U.Unbounded_String;
      Redirs           : not null access Awk_CLI.Redirections.Redirection_Vectors.Vector;
      Live_Input       : Live_Input_Reader;
      Live_Output      : Live_Output_Writer;
      Live_Redirection : Live_Redirection_Writer;
      Live_Command     : Live_Command_Reader;
      Live_User_Data   : System.Address);

   --  @param User_Data Address of Stream_State.
   --  @param Filename AWK-visible input filename.
   --  @param Text Next input text chunk.
   --  @param End_Of_Input Whether no more memory-backed inputs are available.
   procedure Read_Text
     (User_Data    : System.Address;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean);

   --  @param User_Data Address of Stream_State.
   --  @param Operand_Index Runtime operand index requested by awklib.
   --  @param Filename AWK-visible input filename.
   --  @param Text Next input text chunk.
   --  @param End_Of_Input Whether this operand is at EOF.
   procedure Read_Operand_Text
     (User_Data     : System.Address;
      Operand_Index : Positive;
      Filename      : out U.Unbounded_String;
      Text          : out U.Unbounded_String;
      End_Of_Input  : out Boolean);

   --  @param User_Data Address of Stream_State.
   --  @param Text Exact AWK standard output.
   procedure Write_Output (User_Data : System.Address; Text : String);

   --  @param User_Data Address of Stream_State.
   --  @param Name AWK redirection target.
   --  @param Text Exact redirected output.
   --  @param Append Whether append semantics are requested.
   --  @param Truncate Whether awklib reports truncate intent.
   procedure Write_Redirection
     (User_Data : System.Address;
      Name      : String;
      Text      : String;
      Append    : Boolean;
      Truncate  : Boolean);

   --  @param User_Data Address of Stream_State.
   --  @param Command Host command text requested by awklib.
   --  @param Text Captured command output.
   --  @param Available Whether command output is available.
   procedure Read_Command
     (User_Data : System.Address;
      Command   : String;
      Text      : out U.Unbounded_String;
      Available : out Boolean);

   --  @param State Callback state to inspect.
   --  @return True when any callback reported a failure.
   function Failed (State : Stream_State) return Boolean;

   --  @param State Callback state to inspect.
   --  @return Structured diagnostic for the recorded failure.
   function Failure (State : Stream_State) return Awk_CLI.Diagnostics.Diagnostic
     with Pre => Failed (State);

private
   type Input_Vector_Access is access constant Awk_CLI.Inputs.Input_File_Vectors.Vector;
   type Output_Access is access all U.Unbounded_String;
   type Redirection_Vector_Access is access all Awk_CLI.Redirections.Redirection_Vectors.Vector;

   type Stream_State is limited record
      Inputs           : Input_Vector_Access;
      Live_Input       : Live_Input_Reader := null;
      Output           : Output_Access;
      Redirs           : Redirection_Vector_Access;
      Live_Output      : Live_Output_Writer := null;
      Live_Redirection : Live_Redirection_Writer := null;
      Live_Command     : Live_Command_Reader := null;
      Live_User_Data   : System.Address := System.Null_Address;
      Has_Failure      : Boolean := False;
      Failure_Value    : Awk_CLI.Diagnostics.Diagnostic;
      Input_Index      : Natural := 0;
   end record;
end Awk_CLI.Execution.Callbacks;
