with Ada.Directories;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with GNAT.OS_Lib;
with Hostkit.Fs;
with Hostkit.Metadata;

package body Command_Tests.Surface_Smoke.Helpers is
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;

   procedure Assert_Full_Mode_When_Available (Path : String; Expected : Natural; Label : String) is
      Available : Boolean;
      Actual    : constant Natural := Hostkit.Metadata.File_Permission_Bits (Path, Available);
   begin
      --  Only a host's own mode bits carry setuid, setgid and sticky; a mode
      --  rendered from an ACL (Windows) has the permission bits alone.
      if Hostkit.Metadata.Permissions_Supported and then Available then
         if Hostkit.Metadata.Mode_Bits_Are_Native then
            AUnit.Assertions.Assert (Actual mod 8#10000# = Expected, Label);
         else
            AUnit.Assertions.Assert (Actual mod 8#1000# = Expected mod 8#1000#, Label);
         end if;
      end if;
   end Assert_Full_Mode_When_Available;

   procedure Assert_Mode_When_Available (Path : String; Expected : Natural; Label : String) is
      Available : Boolean;
      Actual    : constant Natural := Hostkit.Metadata.File_Permission_Bits (Path, Available);
   begin
      if Hostkit.Metadata.Permissions_Supported and then Available then
         AUnit.Assertions.Assert
           (Actual mod 8#1000# = Expected,
            Label & ": mode " & Octal (Actual mod 8#1000#) & ", expected " & Octal (Expected));
      end if;
   end Assert_Mode_When_Available;

   procedure Create_Symbolic_Link_If_Supported (Target, Link : String) is
      Created : constant Boolean := Hostkit.Fs.Create_Link (Target, Link);
      pragma Unreferenced (Created);
   begin
      null;
   end Create_Symbolic_Link_If_Supported;

   function Fixture_Path (Name : String) return String is
   begin
      return Command_Tests.Surface_Smoke.Fixtures.Fixture_File (Name);
   end Fixture_Path;

   function Large_Copy_Data return String is
      Data : String (1 .. 70 * 1024);
   begin
      for I in Data'Range loop
         Data (I) := Character'Val ((I - Data'First) mod 256);
      end loop;

      return Data;
   end Large_Copy_Data;

   function Octal (Mode : Natural) return String is
      Digits_Of : constant String := "01234567";
   begin
      return [Digits_Of (Mode / 64 mod 8 + 1), Digits_Of (Mode / 8 mod 8 + 1), Digits_Of (Mode mod 8 + 1)];
   end Octal;

   procedure Prepare_Search_Fixtures is
      use Command_Tests.Surface_Smoke.Fixtures;
      FIFO_Created   : constant Boolean := Hostkit.Fs.Create_FIFO (Cp_FIFO_Source, 8#600#);
      Socket_Created : constant Boolean := Hostkit.Fs.Create_Socket (Cp_Socket_Source, 8#600#);
      pragma Unreferenced (FIFO_Created, Socket_Created);
   begin
      Write_File (Source, "copy-data");
      Write_File (Other, "other-data");
      Ada.Directories.Create_Directory (Made);
      Write_File (Made & "/command-source.txt", "copy-data");
      Write_File (Made & "/command-other.txt", "other-data");
      Ada.Directories.Create_Path (Tree & "/sub");
      Write_File (Tree & "/sub/file.txt", "tree-data");
      Create_Symbolic_Link_If_Supported (Source, Symlinked);
   end Prepare_Search_Fixtures;

   procedure Remove_Any (Path : String) is
   begin
      if Hostkit.Fs.Is_Link (Path) then
         AUnit.Assertions.Assert (Hostkit.Fs.Delete_Link (Path), "cleanup link failed for " & Path);
      elsif Ada.Directories.Exists (Path) then
         if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
            Ada.Directories.Delete_Tree (Path);
         else
            declare
               Deleted : Boolean := False;
            begin
               GNAT.OS_Lib.Delete_File (Path, Deleted);
               if not Deleted then
                  Ada.Directories.Delete_File (Path);
               end if;
            end;
         end if;
      end if;
   exception
      when others =>
         AUnit.Assertions.Assert (False, "cleanup failed for " & Path);
   end Remove_Any;

   procedure Remove_Fixtures is
      use Command_Tests.Surface_Smoke.Fixtures;
   begin
      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Large_Source);
      Remove_Any (Large_Target);
      Remove_Any (Dash_Target);
      Remove_Any (Linked);
      Remove_Any (Link_Command_Target);
      Remove_Any (Symlinked);
      Remove_Any (Cp_Symlinked);
      Remove_Any (Link_Dir);
      Remove_Any (Moved);
      Remove_Any (Made);
      Remove_Any (Mkfifo_Target);
      Remove_Any (Symbolic_Mode_Dir);
      Remove_Any (Relative_Mode_Dir);
      Remove_Any (Remove_Dir);
      Remove_Any (Rm_Interactive);
      Remove_Any (Multi);
      Remove_Any (Other);
      Remove_Any (Tree);
      Remove_Any (Tree_Copy);
      Remove_Any (Sort_Out);
      Remove_Any (Empty);
      Remove_Any (Cp_Directory_Source);
      Remove_Any (Cp_Directory_Target);
      Remove_Any (Cp_FIFO_Source);
      Remove_Any (Cp_FIFO_Target);
      Remove_Any (Cp_Socket_Source);
      Remove_Any (Cp_Socket_Target);
      Remove_Any (Parent_Block);
      Remove_Any (Option_Dir);
      Remove_Any (Touched);
      Remove_Any (No_Create);
      Remove_Any (Tee_Out);
      Remove_Any (Chmod_Target);
      Remove_Any (Cksum_File);
      Remove_Any (Cmp_First);
      Remove_Any (Cmp_Second);
      Remove_Any (Paste_First);
      Remove_Any (Paste_Second);
      Remove_Any (Cut_File);
      Remove_Any (Comm_First);
      Remove_Any (Comm_Second);
      Remove_Any (Od_File);
      Remove_Any (Ls_Dir);
      Remove_Any (Ls_Other_Dir);
      Remove_Any (Split_Input);
      Remove_Any (Split_Prefix & "aa");
      Remove_Any (Split_Prefix & "ab");
      Remove_Any (Split_Prefix & "ac");
      Remove_Any (Split_Long_Prefix & "aa");
      Remove_Any (Split_Long_Prefix & "ab");
      Remove_Any (Split_Long_Prefix & "aaa");
      Remove_Any (Split_Long_Prefix & "aab");
      Remove_Any (Split_Long_Prefix & "aac");
   end Remove_Fixtures;

   procedure Restore_Fixtures is
      use Command_Tests.Surface_Smoke.Fixtures;
   begin
      Remove_Fixtures;
      --  The option-operands directory is tracked: put back what git has.
      Ada.Directories.Create_Path (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "-c"), "x" & EOL);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "x" & EOL);
   end Restore_Fixtures;

   function Time_Near (Actual, Expected : Ada.Calendar.Time) return Boolean is
      Difference : constant Duration := Actual - Expected;
   begin
      return abs Difference <= 2.0;
   end Time_Near;

   function Trim_Natural (Value : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left);
   end Trim_Natural;

end Command_Tests.Surface_Smoke.Helpers;
