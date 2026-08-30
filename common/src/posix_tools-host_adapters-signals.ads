package Posix_Tools.Host_Adapters.Signals is
   type Signal is
     (Interrupt,
      Quit,
      Terminate_Signal,
      Kill,
      Hangup,
      Stop,
      Terminal_Stop,
      Continue,
      Pipe,
      Background_Read,
      Background_Write,
      Window_Change,
      Child);
   type Disposition is (Default_Disposition, Ignore_Disposition, Unknown_Disposition);

   function Is_Supported (Item : Signal) return Boolean;
   function Name (Item : Signal) return String;
   function Number (Item : Signal) return Integer;
   function From_Number (Value : Integer; Item : out Signal) return Boolean
     with Post =>
       (if not From_Number'Result then Item = Terminate_Signal);
   function Send_To_Process (Process_Id : Integer; Item : Signal) return Boolean;
   function Current_Disposition (Item : Signal; Value : out Disposition) return Boolean
     with Post =>
       (if not Current_Disposition'Result then Value = Unknown_Disposition);
   function Set_Disposition (Item : Signal; Value : Disposition) return Boolean
     with Post =>
       (if Value = Unknown_Disposition then not Set_Disposition'Result);
end Posix_Tools.Host_Adapters.Signals;
