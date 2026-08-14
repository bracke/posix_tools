with Hostkit.Host;
with Hostkit.Process;

package body Posix_Tools.Host_Adapters.Host is
   function Current return Host_Kind is
   begin
      case Hostkit.Host.Current is
         when Hostkit.Host.Linux =>
            return Linux;
         when Hostkit.Host.MacOS =>
            return MacOS;
         when Hostkit.Host.Windows =>
            return Windows;
         when Hostkit.Host.Unsupported =>
            return Unsupported;
      end case;
   end Current;

   function Current_User_Id (User_Id : out Natural) return Boolean is
   begin
      return Hostkit.Process.Current_User_Id (User_Id);
   end Current_User_Id;

   function Current_Group_Id (Group_Id : out Natural) return Boolean is
   begin
      return Hostkit.Process.Current_Group_Id (Group_Id);
   end Current_Group_Id;

   function Current_Supplementary_Group_Ids
     (Groups : out Group_Id_List;
      Last   : out Natural)
      return Boolean
   is
      Host_Groups : Hostkit.Process.Group_Id_List (1 .. Groups'Length);
      Host_Last   : Natural := 0;
      Ok          : constant Boolean :=
        Hostkit.Process.Current_Supplementary_Group_Ids (Host_Groups, Host_Last);
   begin
      for Index in Groups'Range loop
         Groups (Index) := 0;
      end loop;

      Last := Natural'Min (Host_Last, Groups'Length);
      if Last > 0 then
         for Offset in 0 .. Last - 1 loop
            Groups (Groups'First + Offset) := Host_Groups (Host_Groups'First + Offset);
         end loop;
      end if;

      return Ok;
   exception
      when others =>
         for Index in Groups'Range loop
            Groups (Index) := 0;
         end loop;
         Last := 0;
         return False;
   end Current_Supplementary_Group_Ids;

   function Native_Locale return String is
   begin
      return Hostkit.Host.Native_Locale;
   end Native_Locale;

   function Login_Name return String is
   begin
      return Hostkit.Host.Login_Name;
   end Login_Name;

   function Own_Process_Id return Integer is
   begin
      return Hostkit.Host.Own_Process_Id;
   end Own_Process_Id;

   function System_Name return String is
   begin
      return Hostkit.Host.System_Name;
   end System_Name;

   function Node_Name return String is
   begin
      return Hostkit.Host.Node_Name;
   end Node_Name;

   function Release_Name return String is
   begin
      return Hostkit.Host.Release_Name;
   end Release_Name;

   function Version_Name return String is
   begin
      return Hostkit.Host.Version_Name;
   end Version_Name;

   function Machine_Name return String is
   begin
      return Hostkit.Host.Machine_Name;
   end Machine_Name;
end Posix_Tools.Host_Adapters.Host;
