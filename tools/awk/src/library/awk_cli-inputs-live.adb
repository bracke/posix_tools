with Awk_CLI.Inputs.Live.Activation;
with Awk_CLI.Inputs.Live.Reading;
with Awk_CLI.Live_Context_Callbacks;
with System.Address_To_Access_Conversions;

package body Awk_CLI.Inputs.Live is
   use type U.Unbounded_String;
   use type Awk_CLI.Platform.Read_Status;

   package State_Access is new System.Address_To_Access_Conversions (Live_Input_State);

   procedure Initialize
     (State    : out Live_Input_State;
      Context  : in out Invocation_Context;
      Operands : aliased Awk_CLI.Operands.Operand_Vectors.Vector) is separate;

   procedure Close (State : in out Live_Input_State) is separate;

   function Auxiliary_Files
     (Context : Invocation_Context) return Input_File_Vectors.Vector is separate;

   function Read
     (User_Data    : System.Address;
      Operand_Index : Positive;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status is separate;

   function Write_Output
     (User_Data : System.Address;
      Content   : String) return Boolean is separate;

   function Write_Redirection
     (User_Data : System.Address;
      Path      : String;
      Content   : String;
      Append    : Boolean) return Awk_CLI.Redirections.Write_Status is separate;

   function Read_Command
     (User_Data : System.Address;
      Command   : String;
      Output    : out U.Unbounded_String) return Boolean is separate;
end Awk_CLI.Inputs.Live;
