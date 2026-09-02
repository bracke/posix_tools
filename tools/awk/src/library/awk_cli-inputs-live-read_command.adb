separate (Awk_CLI.Inputs.Live)
function Read_Command
  (User_Data : System.Address;
   Command   : String;
   Output    : out U.Unbounded_String) return Boolean
is
   State : constant State_Access.Object_Pointer :=
     State_Access.To_Pointer (User_Data);
begin
   return
     Awk_CLI.Live_Context_Callbacks.Read_Command
       (State.Context.all, Command, Output);
end Read_Command;
