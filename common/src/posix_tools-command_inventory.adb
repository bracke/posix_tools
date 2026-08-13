package body Posix_Tools.Command_Inventory is
   type Command_Descriptor is record
      Executable    : access constant String;
      Crate         : access constant String;
      Package_Name  : access constant String;
      Posix_Status  : access constant String;
   end record;

   Basename_Exe : aliased constant String := "basename";
   Cat_Exe      : aliased constant String := "cat";
   Cp_Exe       : aliased constant String := "cp";
   Date_Exe     : aliased constant String := "date";
   Dd_Exe       : aliased constant String := "dd";
   Dirname_Exe  : aliased constant String := "dirname";
   Echo_Exe     : aliased constant String := "echo";
   Env_Exe      : aliased constant String := "env";
   False_Exe    : aliased constant String := "false";
   Find_Exe     : aliased constant String := "find";
   Head_Exe     : aliased constant String := "head";
   Ln_Exe       : aliased constant String := "ln";
   Mkdir_Exe    : aliased constant String := "mkdir";
   Mv_Exe       : aliased constant String := "mv";
   Printf_Exe   : aliased constant String := "printf";
   Pwd_Exe      : aliased constant String := "pwd";
   Rm_Exe       : aliased constant String := "rm";
   Rmdir_Exe    : aliased constant String := "rmdir";
   Sort_Exe     : aliased constant String := "sort";
   Tail_Exe     : aliased constant String := "tail";
   Tee_Exe      : aliased constant String := "tee";
   Test_Exe     : aliased constant String := "test";
   Touch_Exe    : aliased constant String := "touch";
   Tr_Exe       : aliased constant String := "tr";
   True_Exe     : aliased constant String := "true";
   Uniq_Exe     : aliased constant String := "uniq";
   Wc_Exe       : aliased constant String := "wc";
   Xargs_Exe    : aliased constant String := "xargs";

   Basename_Crate : aliased constant String := "posix_tools_basename";
   Cat_Crate      : aliased constant String := "posix_tools_cat";
   Cp_Crate       : aliased constant String := "posix_tools_cp";
   Date_Crate     : aliased constant String := "posix_tools_date";
   Dd_Crate       : aliased constant String := "posix_tools_dd";
   Dirname_Crate  : aliased constant String := "posix_tools_dirname";
   Echo_Crate     : aliased constant String := "posix_tools_echo";
   Env_Crate      : aliased constant String := "posix_tools_env";
   False_Crate    : aliased constant String := "posix_tools_false";
   Find_Crate     : aliased constant String := "posix_tools_find";
   Head_Crate     : aliased constant String := "posix_tools_head";
   Ln_Crate       : aliased constant String := "posix_tools_ln";
   Mkdir_Crate    : aliased constant String := "posix_tools_mkdir";
   Mv_Crate       : aliased constant String := "posix_tools_mv";
   Printf_Crate   : aliased constant String := "posix_tools_printf";
   Pwd_Crate      : aliased constant String := "posix_tools_pwd";
   Rm_Crate       : aliased constant String := "posix_tools_rm";
   Rmdir_Crate    : aliased constant String := "posix_tools_rmdir";
   Sort_Crate     : aliased constant String := "posix_tools_sort";
   Tail_Crate     : aliased constant String := "posix_tools_tail";
   Tee_Crate      : aliased constant String := "posix_tools_tee";
   Test_Crate     : aliased constant String := "posix_tools_test";
   Touch_Crate    : aliased constant String := "posix_tools_touch";
   Tr_Crate       : aliased constant String := "posix_tools_tr";
   True_Crate     : aliased constant String := "posix_tools_true";
   Uniq_Crate     : aliased constant String := "posix_tools_uniq";
   Wc_Crate       : aliased constant String := "posix_tools_wc";
   Xargs_Crate    : aliased constant String := "posix_tools_xargs";

   Basename_Pkg : aliased constant String := "Posix_Tools.Commands.Basename";
   Cat_Pkg      : aliased constant String := "Posix_Tools.Commands.Cat";
   Cp_Pkg       : aliased constant String := "Posix_Tools.Commands.Cp";
   Date_Pkg     : aliased constant String := "Posix_Tools.Commands.Date";
   Dd_Pkg       : aliased constant String := "Posix_Tools.Commands.Dd";
   Dirname_Pkg  : aliased constant String := "Posix_Tools.Commands.Dirname";
   Echo_Pkg     : aliased constant String := "Posix_Tools.Commands.Echo";
   Env_Pkg      : aliased constant String := "Posix_Tools.Commands.Env";
   False_Pkg    : aliased constant String := "Posix_Tools.Commands.False_Command";
   Find_Pkg     : aliased constant String := "Posix_Tools.Commands.Find";
   Head_Pkg     : aliased constant String := "Posix_Tools.Commands.Head";
   Ln_Pkg       : aliased constant String := "Posix_Tools.Commands.Ln";
   Mkdir_Pkg    : aliased constant String := "Posix_Tools.Commands.Mkdir";
   Mv_Pkg       : aliased constant String := "Posix_Tools.Commands.Mv";
   Printf_Pkg   : aliased constant String := "Posix_Tools.Commands.Printf";
   Pwd_Pkg      : aliased constant String := "Posix_Tools.Commands.Pwd";
   Rm_Pkg       : aliased constant String := "Posix_Tools.Commands.Rm";
   Rmdir_Pkg    : aliased constant String := "Posix_Tools.Commands.Rmdir";
   Sort_Pkg     : aliased constant String := "Posix_Tools.Commands.Sort";
   Tail_Pkg     : aliased constant String := "Posix_Tools.Commands.Tail";
   Tee_Pkg      : aliased constant String := "Posix_Tools.Commands.Tee";
   Test_Pkg     : aliased constant String := "Posix_Tools.Commands.Test_Command";
   Touch_Pkg    : aliased constant String := "Posix_Tools.Commands.Touch";
   Tr_Pkg       : aliased constant String := "Posix_Tools.Commands.Tr";
   True_Pkg     : aliased constant String := "Posix_Tools.Commands.True_Command";
   Uniq_Pkg     : aliased constant String := "Posix_Tools.Commands.Uniq";
   Wc_Pkg       : aliased constant String := "Posix_Tools.Commands.Wc";
   Xargs_Pkg    : aliased constant String := "Posix_Tools.Commands.Xargs";

   Conforming_With_Extensions : aliased constant String := "conforming_with_extensions";
   Known_Deviation            : aliased constant String := "known_deviation";

   Inventory : constant array (Positive range 1 .. Command_Count) of Command_Descriptor :=
     [1  => (Basename_Exe'Access, Basename_Crate'Access, Basename_Pkg'Access, Conforming_With_Extensions'Access),
      2  => (Cat_Exe'Access, Cat_Crate'Access, Cat_Pkg'Access, Conforming_With_Extensions'Access),
      3  => (Cp_Exe'Access, Cp_Crate'Access, Cp_Pkg'Access, Conforming_With_Extensions'Access),
      4  => (Date_Exe'Access, Date_Crate'Access, Date_Pkg'Access, Conforming_With_Extensions'Access),
      5  => (Dd_Exe'Access, Dd_Crate'Access, Dd_Pkg'Access, Conforming_With_Extensions'Access),
      6  => (Dirname_Exe'Access, Dirname_Crate'Access, Dirname_Pkg'Access, Conforming_With_Extensions'Access),
      7  => (Echo_Exe'Access, Echo_Crate'Access, Echo_Pkg'Access, Conforming_With_Extensions'Access),
      8  => (Env_Exe'Access, Env_Crate'Access, Env_Pkg'Access, Conforming_With_Extensions'Access),
      9  => (False_Exe'Access, False_Crate'Access, False_Pkg'Access, Conforming_With_Extensions'Access),
      10 => (Find_Exe'Access, Find_Crate'Access, Find_Pkg'Access, Conforming_With_Extensions'Access),
      11 => (Head_Exe'Access, Head_Crate'Access, Head_Pkg'Access, Conforming_With_Extensions'Access),
      12 => (Ln_Exe'Access, Ln_Crate'Access, Ln_Pkg'Access, Conforming_With_Extensions'Access),
      13 => (Mkdir_Exe'Access, Mkdir_Crate'Access, Mkdir_Pkg'Access, Conforming_With_Extensions'Access),
      14 => (Mv_Exe'Access, Mv_Crate'Access, Mv_Pkg'Access, Conforming_With_Extensions'Access),
      15 => (Printf_Exe'Access, Printf_Crate'Access, Printf_Pkg'Access, Conforming_With_Extensions'Access),
      16 => (Pwd_Exe'Access, Pwd_Crate'Access, Pwd_Pkg'Access, Conforming_With_Extensions'Access),
      17 => (Rm_Exe'Access, Rm_Crate'Access, Rm_Pkg'Access, Conforming_With_Extensions'Access),
      18 => (Rmdir_Exe'Access, Rmdir_Crate'Access, Rmdir_Pkg'Access, Conforming_With_Extensions'Access),
      19 => (Sort_Exe'Access, Sort_Crate'Access, Sort_Pkg'Access, Conforming_With_Extensions'Access),
      20 => (Tail_Exe'Access, Tail_Crate'Access, Tail_Pkg'Access, Conforming_With_Extensions'Access),
      21 => (Tee_Exe'Access, Tee_Crate'Access, Tee_Pkg'Access, Conforming_With_Extensions'Access),
      22 => (Test_Exe'Access, Test_Crate'Access, Test_Pkg'Access, Conforming_With_Extensions'Access),
      23 => (Touch_Exe'Access, Touch_Crate'Access, Touch_Pkg'Access, Conforming_With_Extensions'Access),
      24 => (Tr_Exe'Access, Tr_Crate'Access, Tr_Pkg'Access, Conforming_With_Extensions'Access),
      25 => (True_Exe'Access, True_Crate'Access, True_Pkg'Access, Conforming_With_Extensions'Access),
      26 => (Uniq_Exe'Access, Uniq_Crate'Access, Uniq_Pkg'Access, Conforming_With_Extensions'Access),
      27 => (Wc_Exe'Access, Wc_Crate'Access, Wc_Pkg'Access, Conforming_With_Extensions'Access),
      28 => (Xargs_Exe'Access, Xargs_Crate'Access, Xargs_Pkg'Access, Conforming_With_Extensions'Access)];

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
