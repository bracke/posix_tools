package Awk_CLI.Inputs.Live.Activation is
   --  Operand activation helpers for live awklib input callbacks.

   --  @param State Live callback state to update.
   procedure Close_Active_Input (State : in out Live_Input_State);

   --  @param State Live callback state to update.
   --  @param Operand_Index Runtime operand index requested by awklib.
   --  @return Host read status for selecting the operand.
   function Activate_Operand
     (State         : in out Live_Input_State;
      Operand_Index : Positive) return Awk_CLI.Platform.Read_Status;
end Awk_CLI.Inputs.Live.Activation;
