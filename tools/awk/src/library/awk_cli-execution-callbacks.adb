with System.Address_To_Access_Conversions;

package body Awk_CLI.Execution.Callbacks is
   use type Awk_CLI.Platform.Read_Status;

   --  awklib's streaming callbacks carry one opaque address. The objects
   --  referenced here are aliased locals in Execute_Core and remain alive until
   --  the synchronous awklib run returns. Do not store these addresses outside
   --  the dynamic extent of that call.
   package Stream_State_Access is new System.Address_To_Access_Conversions (Stream_State);

   function Is_Standard_Input_Name (Filename : U.Unbounded_String) return Boolean is
      Value : constant String := U.To_String (Filename);
   begin
      return Value = "-" or else Value = "";
   end Is_Standard_Input_Name;

   function Make_Input_Failure
     (Status   : Awk_CLI.Platform.Read_Status;
      Filename : U.Unbounded_String) return Awk_CLI.Diagnostics.Diagnostic
   is
   begin
      if Is_Standard_Input_Name (Filename) then
         return
           Awk_CLI.Diagnostics.Make
             ("awk.standard_input.read_failed",
              Awk_CLI.Diagnostics.Error,
              Awk_CLI.Diagnostics.Input);
      elsif Status = Awk_CLI.Platform.Open_Failed then
         return
           Awk_CLI.Diagnostics.Make
             ("awk.input_file.open_failed",
              Awk_CLI.Diagnostics.Error,
              Awk_CLI.Diagnostics.Input,
              Name => "path",
              Value => U.To_String (Filename));
      else
         return
           Awk_CLI.Diagnostics.Make
             ("awk.input_file.read_failed",
              Awk_CLI.Diagnostics.Error,
              Awk_CLI.Diagnostics.Input,
              Name => "path",
              Value => U.To_String (Filename));
      end if;
   end Make_Input_Failure;

   procedure Set_Failure
     (State      : in out Stream_State;
      Diagnostic : Awk_CLI.Diagnostics.Diagnostic) is
   begin
      State.Has_Failure := True;
      State.Failure_Value := Diagnostic;
   end Set_Failure;

   procedure Initialize
     (State            : out Stream_State;
      Inputs           : not null access constant Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Output           : not null access U.Unbounded_String;
      Redirs           : not null access Awk_CLI.Redirections.Redirection_Vectors.Vector;
      Live_Input       : Live_Input_Reader;
      Live_Output      : Live_Output_Writer;
      Live_Redirection : Live_Redirection_Writer;
      Live_Command     : Live_Command_Reader;
      Live_User_Data   : System.Address) is separate;

   procedure Read_Text
     (User_Data    : System.Address;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) is separate;

   procedure Read_Operand_Text
     (User_Data     : System.Address;
      Operand_Index : Positive;
      Filename      : out U.Unbounded_String;
      Text          : out U.Unbounded_String;
      End_Of_Input  : out Boolean) is separate;

   procedure Write_Output (User_Data : System.Address; Text : String) is separate;

   procedure Write_Redirection
     (User_Data : System.Address;
      Name      : String;
      Text      : String;
      Append    : Boolean;
      Truncate  : Boolean) is separate;

   procedure Read_Command
     (User_Data : System.Address;
      Command   : String;
      Text      : out U.Unbounded_String;
      Available : out Boolean) is separate;

   function Failed (State : Stream_State) return Boolean is (State.Has_Failure);

   function Failure (State : Stream_State) return Awk_CLI.Diagnostics.Diagnostic is
     (State.Failure_Value);
end Awk_CLI.Execution.Callbacks;
