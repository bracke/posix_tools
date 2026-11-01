with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Hostkit.Fs;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Text.Matching;
with GNAT.OS_Lib;

package body Test_Support is
   use type Ada.Directories.File_Kind;

   function No_Args return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      return Result;
   end No_Args;

   function One_Arg (A : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      return Result;
   end One_Arg;

   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      return Result;
   end Two_Args;

   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      return Result;
   end Three_Args;

   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      return Result;
   end Four_Args;

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

   function Work_Path (Name : String) return String is
   begin
      return Hostkit.Fs.Join (Hostkit.Fs.Join ("generated", "test-work"), Name);
   end Work_Path;

   function Contains (Text, Pattern : String) return Boolean is
   begin
      return Posix_Tools.Text.Matching.Contains (Text, Pattern);
   end Contains;

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

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
            Ada.Directories.Delete_Tree (Path);
         else
            Ada.Directories.Delete_File (Path);
         end if;
      end if;
   end Delete_If_Exists;

   function Symbolic_Links_Expected return Boolean is
     (GNAT.OS_Lib.Directory_Separator = '/');

   function FIFOs_Expected return Boolean is
     (GNAT.OS_Lib.Directory_Separator = '/');

   procedure Skip_Without_Links (Label : String) is
   begin
      AUnit.Assertions.Assert
        (not Symbolic_Links_Expected,
         Label & ": could not make a symbolic link on a host that has them");
   end Skip_Without_Links;

   procedure Advance (Seed : in out Word_32) is
   begin
      Seed := Seed * 1_664_525 + 1_013_904_223;
   end Advance;

   procedure Advance_C (Seed : in out Word_32) is
   begin
      Seed := Seed * 1_103_515_245 + 12_345;
   end Advance_C;

   function Next_C_Byte (Seed : in out Word_32) return Character is
   begin
      Advance_C (Seed);
      return Character'Val (Natural ((Seed / 16#0001_0000#) mod 256));
   end Next_C_Byte;

   function Seed_Label (Seed : Word_32) return String is
      Hex_Digits : constant String := "0123456789ABCDEF";
      Result     : String (1 .. 8);
      Work       : Word_32 := Seed;
   begin
      for Index in reverse Result'Range loop
         Result (Index) := Hex_Digits (Natural (Work mod 16) + 1);
         Work := Work / 16;
      end loop;

      return "seed 0x" & Result;
   end Seed_Label;
end Test_Support;
