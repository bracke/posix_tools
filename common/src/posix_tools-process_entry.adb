with Ada.Command_Line;
with Posix_Tools.Host_Adapters.Streams;
with Posix_Tools.Version;

package body Posix_Tools.Process_Entry is
   function Is_Identity_Request return Boolean is
   begin
      return Ada.Command_Line.Argument_Count = 1
        and then Ada.Command_Line.Argument (1) = "--posix-tools-identify";
   end Is_Identity_Request;

   function Write_Line (Text : String) return Boolean is
      Ok : Boolean;
   begin
      Posix_Tools.Host_Adapters.Streams.Write_Standard_Output_Line (Text, Ok);
      return Ok;
   end Write_Line;

   function Write_Identity (Command : String) return Boolean is
      Ok : constant Boolean :=
        Write_Line ("schema=1")
        and then Write_Line ("project=" & Posix_Tools.Version.Project_Name)
        and then Write_Line ("command=" & Command)
        and then Write_Line ("version=" & Posix_Tools.Version.Version_String);
   begin
      if Ok then
         Set_Exit_Status (0);
      end if;

      return Ok;
   end Write_Identity;

   procedure Set_Exit_Status (Status : Integer) is
   begin
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Status));
   end Set_Exit_Status;
end Posix_Tools.Process_Entry;
