separate (Awk_CLI.Execution.Callbacks)
procedure Initialize
  (State            : out Stream_State;
   Inputs           : not null access constant Awk_CLI.Inputs.Input_File_Vectors.Vector;
   Output           : not null access U.Unbounded_String;
   Redirs           : not null access Awk_CLI.Redirections.Redirection_Vectors.Vector;
   Live_Input       : Live_Input_Reader;
   Live_Output      : Live_Output_Writer;
   Live_Redirection : Live_Redirection_Writer;
   Live_Command     : Live_Command_Reader;
   Live_User_Data   : System.Address) is
begin
   State.Inputs := Input_Vector_Access (Inputs);
   State.Live_Input := Live_Input;
   State.Output := Output_Access (Output);
   State.Redirs := Redirection_Vector_Access (Redirs);
   State.Live_Output := Live_Output;
   State.Live_Redirection := Live_Redirection;
   State.Live_Command := Live_Command;
   State.Live_User_Data := Live_User_Data;
   State.Has_Failure := False;
   State.Failure_Value :=
     Awk_CLI.Diagnostics.Make
       ("awk.internal.unexpected_exception",
        Awk_CLI.Diagnostics.Internal_Error,
        Awk_CLI.Diagnostics.Internal);
   State.Input_Index := 0;
end Initialize;
