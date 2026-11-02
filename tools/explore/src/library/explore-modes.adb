package body Explore.Modes is
   procedure Ask (Mode, Resume : in out Interaction_Mode; Asked : Question_Mode) is
   begin
      Resume := (if Mode in Filtering | Viewing_Jobs then Mode else Browsing);
      Mode := Asked;
   end Ask;

   procedure Leave (Mode, Resume : in out Interaction_Mode) is
   begin
      Mode := (if Mode in Question_Mode then Resume else Browsing);
      Resume := Browsing;
   end Leave;
end Explore.Modes;
