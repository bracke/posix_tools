package Posix_Tools.Text.Signal_Names
  with SPARK_Mode => On
is
   type Signal_Name is
     (Unknown_Signal_Name,
      Hangup_Name,
      Interrupt_Name,
      Quit_Name,
      Kill_Name,
      Terminate_Name,
      Stop_Name,
      Terminal_Stop_Name,
      Continue_Name,
      Pipe_Name);

   function Is_SIG_Prefixed (Text : String) return Boolean;

   function Known_Signal_Name (Text : String) return Signal_Name;
end Posix_Tools.Text.Signal_Names;
