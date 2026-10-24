with Posix_Tools.Commands.Operation_Reports;
with Posix_Tools.File_Operations.Copying;

package body Posix_Tools.Commands.File_Helpers.Copying is
   procedure Copy_Path
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Source         : String;
      Target         : String;
      Recursive      : Boolean;
      Preserve_Mode  : Boolean;
      Preserve_Links : Boolean;
      Ok             : out Boolean)
   is
      Reports : Posix_Tools.Commands.Operation_Reports.Context_Observer (Context'Access);
   begin
      Posix_Tools.File_Operations.Copying.Copy_Path
        (Source,
         Target,
         (Recursive => Recursive, Preserve_Mode => Preserve_Mode, Preserve_Links => Preserve_Links),
         Reports,
         Ok);
   end Copy_Path;
end Posix_Tools.Commands.File_Helpers.Copying;
