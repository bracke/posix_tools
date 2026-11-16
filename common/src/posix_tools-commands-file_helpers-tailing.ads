with Posix_Tools.Commands.Contexts;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Numbers;

package Posix_Tools.Commands.File_Helpers.Tailing is
   procedure Copy_Line_Suffix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean;
      File      : access Posix_Tools.Host_Adapters.File_System.Follow_File := null);

   procedure Copy_Lines_From
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      First     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean;
      File      : access Posix_Tools.Host_Adapters.File_System.Follow_File := null);
end Posix_Tools.Commands.File_Helpers.Tailing;
