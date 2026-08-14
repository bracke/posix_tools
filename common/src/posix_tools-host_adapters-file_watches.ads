private with Hostkit.Watch;

package Posix_Tools.Host_Adapters.File_Watches is
   type Watch is private;

   procedure Watch_Path (Self : in out Watch; Path : String);
   procedure Release (Self : in out Watch);
   function Changed (Self : in out Watch) return Boolean;
   function Is_Active (Self : Watch) return Boolean;

private
   type Watch is record
      State : Hostkit.Watch.Watch_State;
   end record;
end Posix_Tools.Host_Adapters.File_Watches;
