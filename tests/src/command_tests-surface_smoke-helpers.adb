with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with GNAT.OS_Lib;
with Hostkit.Fs;
with Hostkit.Metadata;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Text.Matching;

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

   procedure Assert_Inventory_Status_Lines (Output_Text, Label : String) is
      LF       : constant Character := Character'Val (10);
      Position : Natural := Output_Text'First;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Prefix : constant String :=
              Posix_Tools.Command_Inventory.Executable (Index) & ": ";
         begin
            AUnit.Assertions.Assert
              (Position <= Output_Text'Last,
               Label & " missing line for " & Posix_Tools.Command_Inventory.Executable (Index));
            AUnit.Assertions.Assert
              (Position + Prefix'Length - 1 <= Output_Text'Last
               and then Output_Text (Position .. Position + Prefix'Length - 1) = Prefix,
               Label & " prefix for " & Posix_Tools.Command_Inventory.Executable (Index));

            while Position <= Output_Text'Last and then Output_Text (Position) /= LF loop
               Position := Position + 1;
            end loop;

            AUnit.Assertions.Assert
              (Position <= Output_Text'Last and then Output_Text (Position) = LF,
               Label & " line terminator for " & Posix_Tools.Command_Inventory.Executable (Index));
            Position := Position + 1;
         end;
      end loop;

      AUnit.Assertions.Assert
        (Position = Output_Text'Last + 1,
         Label & " extra output after inventory lines");
   end Assert_Inventory_Status_Lines;

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

   function Contains (Text, Pattern : String) return Boolean is
   begin
      return Posix_Tools.Text.Matching.Contains (Text, Pattern);
   end Contains;

   procedure Create_Symbolic_Link_If_Supported (Target, Link : String) is
      Created : constant Boolean := Hostkit.Fs.Create_Link (Target, Link);
      pragma Unreferenced (Created);
   begin
      null;
   end Create_Symbolic_Link_If_Supported;

   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      Result.Append (E);
      return Result;
   end Five_Args;

   function Fixture_Path (Name : String) return String is
   begin
      return Command_Tests.Surface_Smoke.Fixtures.Fixture_File (Name);
   end Fixture_Path;

   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      return Result;
   end Four_Args;

   function Inventory_List_Output return String is
      Expected : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Ada.Strings.Unbounded.Append
           (Expected,
            Posix_Tools.Command_Inventory.Executable (Index) & Character'Val (10));
      end loop;

      return Ada.Strings.Unbounded.To_String (Expected);
   end Inventory_List_Output;

   function Large_Copy_Data return String is
      Data : String (1 .. 70 * 1024);
   begin
      for I in Data'Range loop
         Data (I) := Character'Val ((I - Data'First) mod 256);
      end loop;

      return Data;
   end Large_Copy_Data;

   function No_Args return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      return Result;
   end No_Args;

   function Occurrences (Text, Pattern : String) return Natural is
      Count : Natural := 0;
      Index : Positive := Text'First;
   begin
      if Pattern = "" or else Text'Length < Pattern'Length then
         return 0;
      end if;

      while Index <= Text'Last - Pattern'Length + 1 loop
         if Text (Index .. Index + Pattern'Length - 1) = Pattern then
            Count := Count + 1;
            Index := Index + Pattern'Length;
         else
            Index := Index + 1;
         end if;
      end loop;

      return Count;
   end Occurrences;

   function Octal (Mode : Natural) return String is
      Digits_Of : constant String := "01234567";
   begin
      return [Digits_Of (Mode / 64 mod 8 + 1), Digits_Of (Mode / 8 mod 8 + 1), Digits_Of (Mode mod 8 + 1)];
   end Octal;

   function One_Arg (A : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      return Result;
   end One_Arg;

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

   function Six_Args (A, B, C, D, E, F : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      Result.Append (E);
      Result.Append (F);
      return Result;
   end Six_Args;

   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      return Result;
   end Three_Args;

   function Time_Near (Actual, Expected : Ada.Calendar.Time) return Boolean is
      Difference : constant Duration := Actual - Expected;
   begin
      return abs Difference <= 2.0;
   end Time_Near;

   function Trim_Natural (Value : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left);
   end Trim_Natural;

   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      return Result;
   end Two_Args;

   function Work_Path (Name : String) return String is
   begin
      return Hostkit.Fs.Join (Hostkit.Fs.Join ("generated", "test-work"), Name);
   end Work_Path;

   procedure Write_File (Path, Data : String) is
      use type Ada.Streams.Stream_Element_Offset;
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Data'Length));
      Target : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Data'Length = 0 then
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
         Ada.Streams.Stream_IO.Close (File);
         return;
      end if;

      for I in Data'Range loop
         Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Data (I)));
         Target := Target + Ada.Streams.Stream_Element_Offset (1);
      end loop;

      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Ada.Streams.Stream_IO.Write (File, Buffer);
      Ada.Streams.Stream_IO.Close (File);
   end Write_File;
end Command_Tests.Surface_Smoke.Helpers;
