separate (Awk_CLI.Inputs.Live)
function Write_Output
  (User_Data : System.Address;
   Content   : String) return Boolean
is
   State : constant State_Access.Object_Pointer :=
     State_Access.To_Pointer (User_Data);
begin
   return
     Awk_CLI.Live_Context_Callbacks.Write_Output (State.Context.all, Content);
end Write_Output;
