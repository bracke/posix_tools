package Posix_Tools.Process_Entry is
   function Is_Identity_Request return Boolean;

   function Write_Identity (Command : String) return Boolean;

   procedure Set_Exit_Status (Status : Integer);
end Posix_Tools.Process_Entry;
