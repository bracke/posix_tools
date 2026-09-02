separate (Awk_CLI.Execution.Callbacks)
procedure Write_Output (User_Data : System.Address; Text : String) is
   State : constant Stream_State_Access.Object_Pointer :=
     Stream_State_Access.To_Pointer (User_Data);
begin
   if State.Has_Failure then
      return;
   end if;

   if State.Live_Output = null then
      U.Append (State.Output.all, Text);
   elsif not State.Live_Output.all (State.Live_User_Data, Text) then
      Set_Failure
        (State.all,
         Awk_CLI.Diagnostics.Make
           ("awk.standard_output.write_failed",
            Awk_CLI.Diagnostics.Error,
            Awk_CLI.Diagnostics.Output));
   end if;
end Write_Output;
