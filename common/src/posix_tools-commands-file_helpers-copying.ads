with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.File_Helpers.Copying is
   procedure Copy_Path
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Source         : String;
      Target         : String;
      Recursive      : Boolean;
      Preserve_Mode  : Boolean;
      Preserve_Links : Boolean;
      Ok             : out Boolean);
end Posix_Tools.Commands.File_Helpers.Copying;
