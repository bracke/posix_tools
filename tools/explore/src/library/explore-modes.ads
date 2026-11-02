--  What the next key means, and how a question asked over another mode gives
--  the screen back once it is answered: a session's mode machine, apart from
--  the session so that it can be tested.
package Explore.Modes is
   type Interaction_Mode is
     (Browsing,
      Filtering,         --  Typing the filter.
      Renaming,          --  Typing a new name for the selected entry.
      Creating,          --  Typing the name of a file, or of a directory with a slash.
      Changing_Mode,     --  Typing permissions, octal or symbolic.
      Jumping,           --  Typing a path to go to.
      Finding_Names,     --  Typing a name or glob to search for.
      Finding_Text,      --  Typing text to search files for.
      Shelling,          --  Typing a shell command to run on the entries.
      --  Renaming, changing modes and shell commands act on the entries as
      --  they were when asked, whatever a reload does meanwhile.
      Confirming_Delete, --  y deletes the entries asked about, anything else does not.
      Confirming_Quit,   --  y quits and stops the jobs still running or waiting.
      Answering,         --  A running job asks about a target that exists.
      Viewing_Jobs);     --  The jobs panel is open.

   --  The modes that type a line under a label, which Enter commits.
   subtype Prompt_Mode is Interaction_Mode range Renaming .. Shelling;

   --  The modes that wait for a key to answer a question.
   subtype Question_Mode is Interaction_Mode range Confirming_Delete .. Answering;

   --  Ask a question in Asked over Mode. Resume becomes what the answer
   --  returns to: the filter being typed, or the jobs panel, if Mode was
   --  either; otherwise browsing.
   procedure Ask (Mode, Resume : in out Interaction_Mode; Asked : Question_Mode);

   --  Go back from Mode: from a question to what it interrupted, and from
   --  anything else to browsing.
   procedure Leave (Mode, Resume : in out Interaction_Mode);

   --  What the screen shows for Mode, a question over Resume: a prompt; the
   --  jobs panel; the filter being typed. The last two are shown beneath a
   --  question that interrupted them.
   function Prompting (Mode : Interaction_Mode) return Boolean is (Mode in Prompt_Mode);

   function Panel_Open (Mode, Resume : Interaction_Mode) return Boolean is
     (Mode = Viewing_Jobs or else (Mode in Question_Mode and then Resume = Viewing_Jobs));

   function Editing (Mode, Resume : Interaction_Mode) return Boolean is
     (Mode = Filtering or else (Mode in Question_Mode and then Resume = Filtering));
end Explore.Modes;
