with Posix_Tools.Commands.Contexts;
with Posix_Tools.Numbers;

package Posix_Tools.Commands.File_Helpers.Tailing is
   procedure Copy_Line_Suffix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean);

   procedure Copy_Lines_From
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      First     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean);
end Posix_Tools.Commands.File_Helpers.Tailing;
