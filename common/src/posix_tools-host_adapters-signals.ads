package Posix_Tools.Host_Adapters.Signals is
   type Signal is (Interrupt);
   type Disposition is (Default_Disposition, Ignore_Disposition, Unknown_Disposition);

   function Is_Supported (Item : Signal) return Boolean;
   function Current_Disposition (Item : Signal; Value : out Disposition) return Boolean;
   function Set_Disposition (Item : Signal; Value : Disposition) return Boolean;
end Posix_Tools.Host_Adapters.Signals;
