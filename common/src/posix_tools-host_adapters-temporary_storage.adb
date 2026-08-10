with Ada.Directories;
with Hostkit.Fs;

package body Posix_Tools.Host_Adapters.Temporary_Storage is
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;

   function Stored_Path (Self : Store) return String is
   begin
      return Self.Path (Self.Path'First .. Self.Path_Last);
   end Stored_Path;

   function Create (Self : in out Store; Max_Bytes : Posix_Tools.Numbers.Count) return Boolean is
      Directory : constant String := Hostkit.Fs.Create_Temporary_Directory ("posix-tools-tail");
      Path      : constant String := Hostkit.Fs.Join (Directory, "spill.bin");
   begin
      Self.Max_Size := Max_Bytes;
      Self.Current_Size := 0;
      Self.Reading := False;

      if Directory = "" or else Directory'Length > Self.Directory'Length or else Path'Length > Self.Path'Length then
         return False;
      end if;

      Self.Directory_Last := Directory'Length;
      Self.Directory (Self.Directory'First .. Self.Directory'First + Directory'Length - 1) := Directory;
      Self.Path_Last := Path'Length;
      Self.Path (Self.Path'First .. Self.Path'First + Path'Length - 1) := Path;
      Ada.Streams.Stream_IO.Create (Self.File, Ada.Streams.Stream_IO.Out_File, Path);
      return True;
   exception
      when others =>
         Cleanup (Self);
         return False;
   end Create;

   function Append
     (Self   : in out Store;
      Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return Boolean
   is
      Amount : Posix_Tools.Numbers.Count;
   begin
      if Last < Buffer'First then
         return True;
      end if;

      Amount := Posix_Tools.Numbers.Count (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
      if Amount > Self.Max_Size or else Self.Current_Size > Self.Max_Size - Amount then
         return False;
      end if;

      Ada.Streams.Stream_IO.Write (Self.File, Buffer (Buffer'First .. Last));
      Self.Current_Size := Self.Current_Size + Amount;
      return True;
   exception
      when others =>
         return False;
   end Append;

   function Prepare_For_Read (Self : in out Store) return Boolean is
   begin
      if Ada.Streams.Stream_IO.Is_Open (Self.File) then
         Ada.Streams.Stream_IO.Close (Self.File);
      end if;

      Ada.Streams.Stream_IO.Open (Self.File, Ada.Streams.Stream_IO.In_File, Stored_Path (Self));
      Self.Reading := True;
      return True;
   exception
      when others =>
         return False;
   end Prepare_For_Read;

   function Read
     (Self   : in out Store;
      First  : Posix_Tools.Numbers.Count;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
   is
   begin
      if First = 0 or else First > Self.Current_Size + Posix_Tools.Numbers.Count (1) then
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
      end if;

      Ada.Streams.Stream_IO.Set_Index (Self.File, Ada.Streams.Stream_IO.Count (First));
      Ada.Streams.Stream_IO.Read (Self.File, Buffer, Last);
      return True;
   exception
      when others =>
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
   end Read;

   function Size (Self : Store) return Posix_Tools.Numbers.Count is
   begin
      return Self.Current_Size;
   end Size;

   procedure Cleanup (Self : in out Store) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (Self.File) then
         Ada.Streams.Stream_IO.Close (Self.File);
      end if;

      if Self.Path_Last > 0 and then Ada.Directories.Exists (Stored_Path (Self)) then
         Ada.Directories.Delete_File (Stored_Path (Self));
      end if;

      if Self.Directory_Last > 0 then
         declare
            Directory : constant String :=
              Self.Directory (Self.Directory'First .. Self.Directory'First + Self.Directory_Last - 1);
         begin
            if Ada.Directories.Exists (Directory) then
               Ada.Directories.Delete_Directory (Directory);
            end if;
         end;
      end if;

      Self.Directory_Last := 0;
      Self.Path_Last := 0;
      Self.Current_Size := 0;
      Self.Reading := False;
   exception
      when others =>
         Self.Directory_Last := 0;
         Self.Path_Last := 0;
         Self.Current_Size := 0;
         Self.Reading := False;
   end Cleanup;
end Posix_Tools.Host_Adapters.Temporary_Storage;
