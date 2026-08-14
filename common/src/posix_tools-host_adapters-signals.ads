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
   function From_Number (Value : Integer; Item : out Signal) return Boolean;
   function Send_To_Process (Process_Id : Integer; Item : Signal) return Boolean;
   function Current_Disposition (Item : Signal; Value : out Disposition) return Boolean;
   function Set_Disposition (Item : Signal; Value : Disposition) return Boolean;
end Posix_Tools.Host_Adapters.Signals;
