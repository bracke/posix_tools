package body Posix_Tools.Command_Inventory is
   type Command_Descriptor is record
      Executable    : access constant String;
      Crate         : access constant String;
      Package_Name  : access constant String;
      Posix_Status  : access constant String;
   end record;

   Basename_Exe : aliased constant String := "basename";
   Cat_Exe      : aliased constant String := "cat";
   Dirname_Exe  : aliased constant String := "dirname";
   Echo_Exe     : aliased constant String := "echo";
   False_Exe    : aliased constant String := "false";
   Head_Exe     : aliased constant String := "head";
   Pwd_Exe      : aliased constant String := "pwd";
   Tail_Exe     : aliased constant String := "tail";
   True_Exe     : aliased constant String := "true";
   Wc_Exe       : aliased constant String := "wc";

   Basename_Crate : aliased constant String := "posix_tools_basename";
   Cat_Crate      : aliased constant String := "posix_tools_cat";
   Dirname_Crate  : aliased constant String := "posix_tools_dirname";
   Echo_Crate     : aliased constant String := "posix_tools_echo";
   False_Crate    : aliased constant String := "posix_tools_false";
   Head_Crate     : aliased constant String := "posix_tools_head";
   Pwd_Crate      : aliased constant String := "posix_tools_pwd";
   Tail_Crate     : aliased constant String := "posix_tools_tail";
   True_Crate     : aliased constant String := "posix_tools_true";
   Wc_Crate       : aliased constant String := "posix_tools_wc";

   Basename_Pkg : aliased constant String := "Posix_Tools.Commands.Basename";
   Cat_Pkg      : aliased constant String := "Posix_Tools.Commands.Cat";
   Dirname_Pkg  : aliased constant String := "Posix_Tools.Commands.Dirname";
   Echo_Pkg     : aliased constant String := "Posix_Tools.Commands.Echo";
   False_Pkg    : aliased constant String := "Posix_Tools.Commands.False_Command";
   Head_Pkg     : aliased constant String := "Posix_Tools.Commands.Head";
   Pwd_Pkg      : aliased constant String := "Posix_Tools.Commands.Pwd";
   Tail_Pkg     : aliased constant String := "Posix_Tools.Commands.Tail";
   True_Pkg     : aliased constant String := "Posix_Tools.Commands.True_Command";
   Wc_Pkg       : aliased constant String := "Posix_Tools.Commands.Wc";

   Conforming_With_Extensions : aliased constant String := "conforming_with_extensions";
   Known_Deviation            : aliased constant String := "known_deviation";

   Inventory : constant array (Positive range 1 .. 10) of Command_Descriptor :=
     [1  => (Basename_Exe'Access, Basename_Crate'Access, Basename_Pkg'Access, Conforming_With_Extensions'Access),
      2  => (Cat_Exe'Access, Cat_Crate'Access, Cat_Pkg'Access, Conforming_With_Extensions'Access),
      3  => (Dirname_Exe'Access, Dirname_Crate'Access, Dirname_Pkg'Access, Conforming_With_Extensions'Access),
      4  => (Echo_Exe'Access, Echo_Crate'Access, Echo_Pkg'Access, Conforming_With_Extensions'Access),
      5  => (False_Exe'Access, False_Crate'Access, False_Pkg'Access, Conforming_With_Extensions'Access),
      6  => (Head_Exe'Access, Head_Crate'Access, Head_Pkg'Access, Conforming_With_Extensions'Access),
      7  => (Pwd_Exe'Access, Pwd_Crate'Access, Pwd_Pkg'Access, Conforming_With_Extensions'Access),
      8  => (Tail_Exe'Access, Tail_Crate'Access, Tail_Pkg'Access, Known_Deviation'Access),
      9  => (True_Exe'Access, True_Crate'Access, True_Pkg'Access, Conforming_With_Extensions'Access),
      10 => (Wc_Exe'Access, Wc_Crate'Access, Wc_Pkg'Access, Conforming_With_Extensions'Access)];

   function Executable (Index : Positive) return String is
   begin
      return Inventory (Index).Executable.all;
   end Executable;

   function Crate (Index : Positive) return String is
   begin
      return Inventory (Index).Crate.all;
   end Crate;

   function Package_Name (Index : Positive) return String is
   begin
      return Inventory (Index).Package_Name.all;
   end Package_Name;

   function Manifest_Path (Index : Positive) return String is
   begin
      return "tools/" & Executable (Index) & "/alire.toml";
   end Manifest_Path;

   function Project_File_Path (Index : Positive) return String is
   begin
      return "tools/" & Executable (Index) & "/" & Crate (Index) & ".gpr";
   end Project_File_Path;

   function Documentation_Path (Index : Positive) return String is
   begin
      return "docs/commands/" & Executable (Index) & ".md";
   end Documentation_Path;

   function Release_Included (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Release_Included;

   function Posix_Status (Index : Positive) return String is
   begin
      return Inventory (Index).Posix_Status.all;
   end Posix_Status;

   function Has_Help (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Help;

   function Has_Version (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Version;

   function Has_Identity (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Identity;

   function Contains_Executable (Name : String) return Boolean is
   begin
      for I in 1 .. Command_Count loop
         if Executable (I) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Contains_Executable;
end Posix_Tools.Command_Inventory;
