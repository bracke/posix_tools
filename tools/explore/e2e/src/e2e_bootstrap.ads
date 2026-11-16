--  Process bootstrap shared by the E2E parent and session rig.
package E2E_Bootstrap is
   --  Path getters require Prepare to have run in this process or an ancestor.
   --  Program_Error is raised with an actionable message otherwise.
   function Crate_Root return String;
   function Explore_Binary return String;
   function Launcher_Path return String;
   function Program_Path return String;
   function Quoted (Text : String) return String;
   function Request_Path return String;
   function Run_Root return String;

   --  Publish Root and the crate location, then create the immutable launcher.
   procedure Prepare (Root : String);
end E2E_Bootstrap;
