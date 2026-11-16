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
   elsif Text'Length >= Output_Buffer_Size then
      Flush_Output (State.all);
      if not State.Has_Failure
        and then not State.Live_Output.all (State.Live_User_Data, Text)
      then
         Set_Failure
           (State.all,
            Awk_CLI.Diagnostics.Make
              ("awk.standard_output.write_failed",
               Awk_CLI.Diagnostics.Error,
               Awk_CLI.Diagnostics.Output));
      end if;
   else
      U.Append (State.Live_Output_Buffer, Text);
      if U.Length (State.Live_Output_Buffer) >= Output_Buffer_Size then
         Flush_Output (State.all);
      end if;
   end if;
end Write_Output;
