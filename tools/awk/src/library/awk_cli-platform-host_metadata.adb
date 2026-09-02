separate (Awk_CLI.Platform)
package body Host_Metadata is
   function Is_Terminal (File_Descriptor : Interfaces.C_Streams.int) return Boolean is
   begin
      return Interfaces.C_Streams.isatty (File_Descriptor) = 1;
   exception
      when Constraint_Error | Program_Error =>
         return False;
   end Is_Terminal;

   function No_Color_Active return Boolean is
     (Environment_Variable_Exists ("NO_COLOR"));

   function Locale return String is
      LC_All : constant String := Environment_Value_Or_Empty ("LC_ALL");
      Lang   : constant String := Environment_Value_Or_Empty ("LANG");
      Native : constant String := Hostkit.Host.Native_Locale;
   begin
      if LC_All /= "" then
         return LC_All;
      elsif Lang /= "" then
         return Lang;
      elsif Native /= "" then
         return Native;
      else
         return "en";
      end if;
   exception
      when Constraint_Error | Program_Error =>
         return "en";
   end Locale;

   function Catalog_Path return String is
      Executable_Dir : constant String := Hostkit.Fs.Own_Executable_Directory;

      function Child (Directory, Name : String) return String is
        (Ada.Directories.Compose
           (Containing_Directory => Directory,
            Name                 => Name));

      function Catalog_Under (Base : String) return String is
        (Child (Child (Child (Base, "resources"), "messages"), "catalog.txt"));

      function Message_Catalog_Under (Base : String) return String is
        (Child (Child (Base, "messages"), "catalog.txt"));

      function Existing_Catalog (Path : String) return String is
      begin
         if Path /= "" and then Ada.Directories.Exists (Path) then
            return Path;
         else
            return "";
         end if;
      end Existing_Catalog;

      function Installed_Catalog return String is
      begin
         if Executable_Dir = "" then
            return "";
         else
            declare
               Share_Awk : constant String :=
                 Child (Child (Child (Executable_Dir, ".."), "share"), "awk");
               Installed : constant String :=
                 Existing_Catalog (Message_Catalog_Under (Share_Awk));
            begin
               if Installed /= "" then
                  return Installed;
               else
                  return Existing_Catalog (Catalog_Under (Share_Awk));
               end if;
            end;
         end if;
      end Installed_Catalog;

      function Development_Catalog return String is
      begin
         if Executable_Dir = "" then
            return "";
         else
            return Existing_Catalog (Catalog_Under (Child (Executable_Dir, "..")));
         end if;
      end Development_Catalog;
   begin
      declare
         Installed   : constant String := Installed_Catalog;
         Development : constant String := Development_Catalog;
         Local       : constant String :=
           Existing_Catalog ("resources/messages/catalog.txt");
         Test        : constant String :=
           Existing_Catalog ("../resources/messages/catalog.txt");
      begin
         if Installed /= "" then
            return Installed;
         elsif Development /= "" then
            return Development;
         elsif Local /= "" then
            return Local;
         elsif Test /= "" then
            return Test;
         else
            return "resources/messages/catalog.txt";
         end if;
      end;
   end Catalog_Path;
end Host_Metadata;
