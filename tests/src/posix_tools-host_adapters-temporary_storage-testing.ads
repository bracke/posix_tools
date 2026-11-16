package Posix_Tools.Host_Adapters.Temporary_Storage.Testing is
   function Backing_Directory (Self : Store) return String;
   function Backing_Path (Self : Store) return String;
   procedure Close_Backing_File (Self : in out Store);
   procedure Remove_Backing_File (Self : in out Store);
   procedure Force_Cleanup_Failure (Self : in out Store);
   procedure Repair_Cleanup_Failure (Self : in out Store);
end Posix_Tools.Host_Adapters.Temporary_Storage.Testing;
