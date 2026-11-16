with Posix_Tools.Commands.Contexts;
with Posix_Tools.Host_Adapters.Temporary_Storage;

package Posix_Tools.Commands.Spill_Diagnostics is
   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome);

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome);

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Finish_Outcome);

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome);

   procedure Report
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Outcome : Posix_Tools.Host_Adapters.Temporary_Storage.Read_Outcome);
end Posix_Tools.Commands.Spill_Diagnostics;
