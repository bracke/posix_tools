with Explore.Files;
with Posix_Tools.Host_Adapters.File_System;

package body Explore.Settings.Storage is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Unbounded renames Ada.Strings.Unbounded;

   --  The largest configuration or bookmarks file read.
   Max_File_Bytes : constant := 1024 * 1024;

   --  Make Path a directory, with any of its parents that are missing;
   --  False when one could not be made.
   function Make_Directories (Path : String) return Boolean;

   procedure Load (Path : String; Into : out Settings; Problems : out Problem_Vectors.Vector) is
      Text : Unbounded.Unbounded_String;
      Ok   : Boolean;
   begin
      Into := (others => <>);
      Problems.Clear;

      if Path'Length = 0 or else not FS.Exists (Path) then
         return;
      end if;

      Explore.Files.Read_Head (Path, Max_File_Bytes, Text, Ok);

      if Ok then
         Parse (Unbounded.To_String (Text), Into, Problems);
      else
         Problems.Append (Problem'(Kind => Unreadable_File, Where => Unbounded.To_Unbounded_String (Path), Line => 0));
      end if;
   end Load;

   function Make_Directories (Path : String) return Boolean is
   begin
      if Path'Length = 0 or else FS.Exists (Path) then
         return True;
      end if;

      for I in reverse Path'First + 1 .. Path'Last loop
         if Path (I) = '/' then
            if not Make_Directories (Path (Path'First .. I - 1)) then
               return False;
            end if;
            exit;
         end if;
      end loop;

      return FS.Create_Directory (Path);
   end Make_Directories;

   function Read_Bookmarks (Path : String) return Bookmark_Maps.Map is
      Text : Unbounded.Unbounded_String;
      Ok   : Boolean;
   begin
      if Path'Length = 0 or else not FS.Exists (Path) then
         return Bookmark_Maps.Empty_Map;
      end if;

      Explore.Files.Read_Head (Path, Max_File_Bytes, Text, Ok);
      return (if Ok then Bookmarks_Value (Unbounded.To_String (Text)) else Bookmark_Maps.Empty_Map);
   end Read_Bookmarks;

   procedure Write_Bookmarks (Path : String; Marks : Bookmark_Maps.Map; Ok : out Boolean) is
   begin
      Ok := False;

      if Path'Length = 0 then
         return;
      end if;

      for I in reverse Path'Range loop
         if Path (I) = '/' then
            if not Make_Directories (Path (Path'First .. I - 1)) then
               return;
            end if;
            exit;
         end if;
      end loop;

      FS.Write_File (Path, Bookmarks_Image (Marks), Append_Mode => False, Ok => Ok);
   exception
      when others =>
         Ok := False;
   end Write_Bookmarks;
end Explore.Settings.Storage;
