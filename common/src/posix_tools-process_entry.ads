package Posix_Tools.Process_Entry is
   function Is_Help_Request return Boolean;

   function Is_Identity_Request return Boolean;

   function Write_Line (Text : String) return Boolean;

   function Write_Plain_Help (Command : String) return Boolean;

   function Write_Identity (Command : String) return Boolean;

   procedure Set_Exit_Status (Status : Integer);

   --  Finish a command process with Status.  Windows uses immediate process
   --  termination because finalizing the GNAT/MinGW tasking runtime after a
   --  successful command can surface an unhandled STATUS_GCC_THROW; the
   --  command owns no state that must survive process teardown.  Other hosts
   --  retain normal Ada finalization.
   procedure Complete (Status : Integer);
end Posix_Tools.Process_Entry;
