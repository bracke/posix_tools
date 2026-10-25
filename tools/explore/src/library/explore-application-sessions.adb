with Posix_Tools.Localization;

package body Explore.Application.Sessions is
   procedure Ask (State : in out Session; Mode : Question_Mode; Question : String) is
   begin
      State.Interaction.Resume :=
        (if State.Interaction.Mode in Filtering | Viewing_Jobs then State.Interaction.Mode else Browsing);
      State.Interaction.Mode := Mode;
      State.Frame.Question := Unbounded.To_Unbounded_String (Question);
   end Ask;

   procedure Complain (State : in out Session; Path : String; Error : Posix_Tools.File_Operations.Operation_Error) is
   begin
      Warn
        (State,
         Path & ": "
         & Posix_Tools.Localization.Text
             (Unbounded.To_String (State.Config.Locale),
              Posix_Tools.File_Operations.Message_Key (Error),
              Posix_Tools.File_Operations.Default_Message (Error)));
   end Complain;

   procedure Leave_Mode (State : in out Session) is
   begin
      State.Interaction.Mode :=
        (if State.Interaction.Mode in Question_Mode then State.Interaction.Resume else Browsing);
      State.Interaction.Resume := Browsing;
      State.Frame.Question := Unbounded.Null_Unbounded_String;
   end Leave_Mode;

   procedure Lose_Terminal (State : in out Session) is
   begin
      State.Terminal_Lost := True;
      State.Quit := True;
   end Lose_Terminal;

   procedure Open_Prompt
     (State   : in out Session;
      Mode    : Prompt_Mode;
      Label   : Unbounded.Unbounded_String;
      Initial : String := "")
   is
   begin
      State.Interaction.Mode := Mode;
      State.Frame.Prompt_Label := Label;
      State.Frame.Prompt_Text := Unbounded.To_Unbounded_String (Initial);
   end Open_Prompt;

   procedure Say (State : in out Session; Text : String) is
   begin
      State.Frame.Message := Unbounded.To_Unbounded_String (Text);
      State.Frame.Message_Is_Error := False;
   end Say;

   procedure Send (State : in out Session; Text : String) is
   begin
      if not Write (Text) then
         Lose_Terminal (State);
      end if;
   end Send;

   procedure Show_Mode (State : in out Session) is
      Mode : constant Interaction_Mode := State.Interaction.Mode;
   begin
      State.Frame.Prompting := Mode in Prompt_Mode;
      State.Frame.Panel_Open :=
        Mode = Viewing_Jobs or else (Mode in Question_Mode and then State.Interaction.Resume = Viewing_Jobs);
      --  A question that interrupted the filter leaves it open beneath.
      State.Frame.Editing :=
        Mode = Filtering or else (Mode in Question_Mode and then State.Interaction.Resume = Filtering);
   end Show_Mode;

   procedure Warn (State : in out Session; Text : String) is
   begin
      State.Frame.Message := Unbounded.To_Unbounded_String (Text);
      State.Frame.Message_Is_Error := True;
   end Warn;
end Explore.Application.Sessions;
