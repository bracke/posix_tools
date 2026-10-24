with Posix_Tools.Commands.Helpers;

package body Posix_Tools.Commands.Operation_Reports is
   overriding procedure Report_Error
     (Self  : in out Context_Observer;
      Path  : String;
      Error : Posix_Tools.File_Operations.Operation_Error)
   is
   begin
      Self.Failed := True;

      if not Self.Quiet then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Self.Context.all,
            Path,
            Posix_Tools.File_Operations.Message_Key (Error),
            Posix_Tools.File_Operations.Default_Message (Error));
      end if;
   end Report_Error;
end Posix_Tools.Commands.Operation_Reports;
