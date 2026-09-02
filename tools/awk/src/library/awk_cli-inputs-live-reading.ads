package Awk_CLI.Inputs.Live.Reading is
   --  Active input reading helpers for live awklib input callbacks.

   --  @param State Live callback state to update.
   --  @param Filename Current AWK-visible filename.
   --  @param Text Chunk read for this call.
   --  @param End_Of_Input Whether this input operand is at EOF.
   --  @return Host read status for this callback.
   function Read_Active
     (State        : in out Live_Input_State;
      Filename     : out U.Unbounded_String;
      Text         : out U.Unbounded_String;
      End_Of_Input : out Boolean) return Awk_CLI.Platform.Read_Status;
end Awk_CLI.Inputs.Live.Reading;
