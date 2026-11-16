with Posix_Tools.Commands.Helpers;

package body Posix_Tools.Commands.Spill_Diagnostics is
   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome)
   is
   begin
      case Outcome is
         when Posix_Tools.Host_Adapters.Temporary_Storage.Create_Complete =>
            null;
         when Posix_Tools.Host_Adapters.Temporary_Storage.Create_Cleanup_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.remove_failed",
               "cannot remove");
         when Posix_Tools.Host_Adapters.Temporary_Storage.Create_Directory_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.create_failed",
               "cannot create directory");
         when Posix_Tools.Host_Adapters.Temporary_Storage.Create_Open_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.open_failed",
               "cannot open file");
         when Posix_Tools.Host_Adapters.Temporary_Storage.Create_Unexpected_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.temporary_storage_failed",
               "cannot create temporary storage");
      end case;
   end Report;

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome)
   is
   begin
      case Outcome is
         when Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete =>
            null;
         when Posix_Tools.Host_Adapters.Temporary_Storage.Append_Capacity_Exceeded =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.resource.count_too_large",
               "count too large");
         when Posix_Tools.Host_Adapters.Temporary_Storage.Append_Write_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.write_failed",
               "cannot write file");
      end case;
   end Report;

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Finish_Outcome)
   is
   begin
      case Outcome is
         when Posix_Tools.Host_Adapters.Temporary_Storage.Finish_Complete =>
            null;
         when Posix_Tools.Host_Adapters.Temporary_Storage.Finish_Close_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.write_failed",
               "cannot write file");
      end case;
   end Report;

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Read_Outcome)
   is
   begin
      case Outcome is
         when Posix_Tools.Host_Adapters.Temporary_Storage.Read_Complete =>
            null;
         when Posix_Tools.Host_Adapters.Temporary_Storage.Read_Not_Prepared
            | Posix_Tools.Host_Adapters.Temporary_Storage.Read_Transfer_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.read_failed",
               "cannot read file");
      end case;
   end Report;

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome)
   is
   begin
      case Outcome is
         when Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Complete =>
            null;
         when Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Close_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.write_failed",
               "cannot write file");
         when Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Open_Failed =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.diagnostic.file.read_failed",
               "cannot read file");
      end case;
   end Report;
end Posix_Tools.Commands.Spill_Diagnostics;
