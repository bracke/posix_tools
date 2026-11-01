with Ada.Streams;
with Explore.Paths;
with Posix_Tools.Host_Adapters.File_System;

package body Explore.Files is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ada.Streams.Stream_Element_Offset;
   use type FS.File_Kind;

   procedure Locate
     (Path      : String;
      Directory : out Ada.Strings.Unbounded.Unbounded_String;
      Name      : out Ada.Strings.Unbounded.Unbounded_String;
      Found     : out Boolean)
   is
   begin
      Directory := Unbounded.Null_Unbounded_String;
      Name := Unbounded.Null_Unbounded_String;
      Found := FS.Exists (Path);

      if not Found then
         return;
      end if;

      declare
         Real : constant String := FS.Real_Path (Path);
      begin
         if FS.Kind (Path) = FS.Directory then
            Directory := Unbounded.To_Unbounded_String (Real);
         else
            Directory := Unbounded.To_Unbounded_String (Explore.Paths.Parent_Of (Real));
            Name := Unbounded.To_Unbounded_String (Explore.Paths.Name_Of (Real));
         end if;
      end;
   exception
      when others =>
         Found := False;
   end Locate;

   procedure Read_Head
     (Path  : String;
      Limit : Positive;
      Data  : out Ada.Strings.Unbounded.Unbounded_String;
      Ok    : out Boolean)
   is
      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
         Room  : constant Natural := Limit - Unbounded.Length (Data);
         Count : constant Natural := Natural'Min (Room, Natural (Last - Buffer'First + 1));
         Chunk : String (1 .. Count);
      begin
         for I in Chunk'Range loop
            Chunk (I) := Character'Val (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (I - 1)));
         end loop;

         Unbounded.Append (Data, Chunk);
         Stop := Unbounded.Length (Data) >= Limit;
      end Take;

      procedure Each is new FS.For_Each_File_Chunk (Take);
   begin
      Data := Unbounded.Null_Unbounded_String;
      Each (Path, Ok);
   exception
      when others =>
         Ok := False;
   end Read_Head;
end Explore.Files;
