with Hostkit.Watch;

package body Posix_Tools.Host_Adapters.File_Watches is
   procedure Watch_Path (Self : in out Watch; Path : String) is
   begin
      Hostkit.Watch.Watch_Path (Self.State, Path);
   end Watch_Path;

   procedure Release (Self : in out Watch) is
   begin
      Hostkit.Watch.Release (Self.State);
   end Release;

   function Changed (Self : in out Watch) return Boolean is
   begin
      return Hostkit.Watch.Poll (Self.State);
   end Changed;

   function Is_Active (Self : Watch) return Boolean is
   begin
      return Hostkit.Watch.Is_Active (Self.State);
   end Is_Active;
end Posix_Tools.Host_Adapters.File_Watches;
