with Ada.Streams;
with Ada.Strings.Unbounded;
with Explore.Format;
with Posix_Tools.Host_Adapters.File_System;
with Tarlib.Entries;
with Tarlib.Errors;
with Tarlib.Inputs;
with Tarlib.Readers;
with Zlib;

package body Explore.Archives is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ada.Streams.Stream_Element_Offset;
   use type Tarlib.Entries.Entry_Kind;
   use type Zlib.Status_Code;

   type Archive_Format is (Not_An_Archive, Zip_Or_7z, Ar, Cpio, Iso, Rar, Tar, Gzip_Tar);

   --  The bytes of a whole file read into memory, handed to tarlib.
   type Memory_Source is new Tarlib.Inputs.Input_Source with record
      Data     : Unbounded.Unbounded_String;
      Position : Natural := 0;
   end record;

   overriding procedure Read
     (Source : in out Memory_Source;
      Data   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset;
      Result : out Tarlib.Errors.Status);

   function Format_Of (Head : String) return Archive_Format;

   function Line (Size : Long_Long_Integer; Name : String; Directory : Boolean) return String is
     ([1 .. Natural'Max (0, 6 - (if Directory then 0 else Format.Size_Image (Size)'Length)) => ' ']
      & (if Directory then "" else Format.Size_Image (Size)) & "  " & Name
      & (if Directory and then (Name'Length = 0 or else Name (Name'Last) /= '/') then "/" else ""));

   procedure List_Tar
     (Data  : Unbounded.Unbounded_String;
      Limit : Positive;
      Lines : out Explore.Model.Path_Vectors.Vector;
      Ok    : out Boolean);

   --  The whole file at Path, when it is at most Limit bytes.
   procedure Read_All (Path : String; Limit : Natural; Data : out Unbounded.Unbounded_String; Ok : out Boolean);

   function Format_Of (Head : String) return Archive_Format is
      function At_Offset (Offset : Natural; Text : String) return Boolean is
        (Head'Length >= Offset + Text'Length
         and then Head (Head'First + Offset .. Head'First + Offset + Text'Length - 1) = Text);
   begin
      if At_Offset (0, "PK" & Character'Val (3) & Character'Val (4))
        or else At_Offset (0, "7z" & Character'Val (16#BC#) & Character'Val (16#AF#) & Character'Val (16#27#)
                              & Character'Val (16#1C#))
      then
         return Zip_Or_7z;
      elsif At_Offset (0, "!<arch>" & Character'Val (10)) then
         return Ar;
      elsif At_Offset (0, "070701") or else At_Offset (0, "070702") or else At_Offset (0, "070707") then
         return Cpio;
      elsif At_Offset (0, "Rar!" & Character'Val (16#1A#) & Character'Val (7)) then
         return Rar;
      elsif At_Offset (257, "ustar") then
         return Tar;
      elsif At_Offset (0, Character'Val (16#1F#) & Character'Val (16#8B#)) then
         return Gzip_Tar;
      elsif At_Offset (32_769, "CD001") then
         return Iso;
      else
         return Not_An_Archive;
      end if;
   end Format_Of;

   function Is_Archive (Head : String) return Boolean is (Format_Of (Head) /= Not_An_Archive);

   procedure List
     (Path  : String;
      Head  : String;
      Limit : Positive;
      Lines : out Explore.Model.Path_Vectors.Vector;
      Ok    : out Boolean)
   is
      Kind   : constant Archive_Format := Format_Of (Head);
      Status : Zlib.Status_Code;

      procedure Take (Members : Zlib.Archive_Entry_Array);

      procedure Take (Members : Zlib.Archive_Entry_Array) is
      begin
         Ok := Status = Zlib.Ok;

         for Member of Members loop
            exit when Natural (Lines.Length) >= Limit;
            Lines.Append
              (Line (Long_Long_Integer (Member.Uncompressed_Size), Unbounded.To_String (Member.Name),
                     Member.Is_Directory));
         end loop;
      end Take;
   begin
      Lines.Clear;
      Ok := False;

      case Kind is
         when Not_An_Archive =>
            null;
         when Zip_Or_7z =>
            Take (Zlib.List_Archive_File_Entries (Path, "", Status));
         when Ar =>
            Take (Zlib.List_Ar_File_Entries (Path, Status));
         when Cpio =>
            Take (Zlib.List_Cpio_File_Entries (Path, Status));
         when Iso =>
            Take (Zlib.List_Iso_File_Entries (Path, Status));
         when Rar =>
            Take (Zlib.List_Rar_File_Entries (Path, Status));
         when Tar | Gzip_Tar =>
            declare
               Data : Unbounded.Unbounded_String;
               Read : Boolean;
            begin
               Read_All (Path, Max_Inflated_Bytes, Data, Read);

               if not Read then
                  return;
               end if;

               if Kind = Gzip_Tar then
                  declare
                     Packed : constant String := Unbounded.To_String (Data);
                     Input  : Zlib.Byte_Array (0 .. Packed'Length - 1);
                  begin
                     for I in Input'Range loop
                        Input (I) := Zlib.Byte (Character'Pos (Packed (Packed'First + I)));
                     end loop;

                     declare
                        Plain : constant Zlib.Byte_Array := Zlib.Inflate_Auto (Input, Status);
                        Text  : String (1 .. Plain'Length);
                     begin
                        --  A gzip file that holds no tar is not listed.
                        if Status /= Zlib.Ok or else Plain'Length < 262 then
                           return;
                        end if;

                        for I in Text'Range loop
                           Text (I) := Character'Val (Plain (Plain'First + I - 1));
                        end loop;

                        if Text (258 .. 262) /= "ustar" then
                           return;
                        end if;

                        Data := Unbounded.To_Unbounded_String (Text);
                     end;
                  end;
               end if;

               List_Tar (Data, Limit, Lines, Ok);
            end;
      end case;
   exception
      when others =>
         Ok := False;
   end List;

   procedure List_Tar
     (Data  : Unbounded.Unbounded_String;
      Limit : Positive;
      Lines : out Explore.Model.Path_Vectors.Vector;
      Ok    : out Boolean)
   is
      Source  : aliased Memory_Source := (Data => Data, Position => 0);
      Archive : Tarlib.Readers.Reader;
      Info    : Tarlib.Readers.Entry_Info;
      Present : Boolean;
      Result  : Tarlib.Errors.Status;
   begin
      Lines.Clear;
      Tarlib.Readers.Initialize (Archive, Source, Result);
      Ok := Tarlib.Errors.Is_Success (Result);

      while Ok and then Natural (Lines.Length) < Limit loop
         Tarlib.Readers.Next_Entry (Archive, Info, Present, Result);
         Ok := Tarlib.Errors.Is_Success (Result);
         exit when not Ok or else not Present;

         Lines.Append
           (Line (Long_Long_Integer (Tarlib.Readers.Size (Info)), Tarlib.Readers.Path (Info),
                  Tarlib.Readers.Kind (Info) = Tarlib.Entries.Directory));
         Tarlib.Readers.Skip_Entry (Archive, Result);
         Ok := Tarlib.Errors.Is_Success (Result);
      end loop;
   end List_Tar;

   overriding procedure Read
     (Source : in out Memory_Source;
      Data   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset;
      Result : out Tarlib.Errors.Status)
   is
      Count : constant Natural :=
        Natural'Min (Data'Length, Unbounded.Length (Source.Data) - Source.Position);
   begin
      for I in 1 .. Count loop
         Data (Data'First + Ada.Streams.Stream_Element_Offset (I - 1)) :=
           Character'Pos (Unbounded.Element (Source.Data, Source.Position + I));
      end loop;

      Source.Position := Source.Position + Count;
      Last := Data'First + Ada.Streams.Stream_Element_Offset (Count) - 1;
      Result := Tarlib.Errors.OK;
   end Read;

   procedure Read_All (Path : String; Limit : Natural; Data : out Unbounded.Unbounded_String; Ok : out Boolean) is
      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
         pragma Unreferenced (Stop);
         Chunk : String (1 .. Natural (Last - Buffer'First + 1));
      begin
         for I in Chunk'Range loop
            Chunk (I) := Character'Val (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (I - 1)));
         end loop;

         Unbounded.Append (Data, Chunk);
      end Take;

      procedure Each is new FS.For_Each_File_Chunk (Take);
   begin
      Data := Unbounded.Null_Unbounded_String;
      Ok := FS.Size (Path) <= Long_Long_Integer (Limit);

      if Ok then
         Each (Path, Ok);
      end if;
   end Read_All;
end Explore.Archives;
