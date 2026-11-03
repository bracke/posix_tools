with Ada.Calendar;
with Ada.Directories;
with Hostkit.Fs;

package body Posix_Tools.Host_Adapters.Temporary_Storage is
   use type Posix_Tools.Numbers.Count;

   package U renames Ada.Strings.Unbounded;

   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. 16 * 1024);

   --  Finalization is best effort; command paths use Try_Cleanup directly
   --  so a failure is observable to the caller.
   procedure Cleanup (Self : in out Store);

   function Stored_Path (Self : Store) return String is
   begin
      return U.To_String (Self.Path);
   end Stored_Path;

   function Stored_Directory (Self : Store) return String is
   begin
      return U.To_String (Self.Directory);
   end Stored_Directory;

   function Spill_Leaf (Directory : String) return String is
      type Word_64 is mod 2 ** 64;

      Hash : Word_64 := 14_695_981_039_346_656_037;

      procedure Mix (Text : String) is
      begin
         for Ch of Text loop
            Hash := (Hash xor Word_64 (Character'Pos (Ch))) * 1_099_511_628_211;
         end loop;
      end Mix;

      function Hex_Image return String is
         Hex_Digits : constant String := "0123456789abcdef";
         Value      : Word_64 := Hash;
         Result     : String (1 .. 16);
      begin
         for I in reverse Result'Range loop
            Result (I) := Hex_Digits (Hex_Digits'First + Natural (Value mod 16));
            Value := Value / 16;
         end loop;

         return Result;
      end Hex_Image;
   begin
      Mix (Directory);
      Mix (Duration'Image (Ada.Calendar.Seconds (Ada.Calendar.Clock)));
      return "spill-" & Hex_Image & ".bin";
   end Spill_Leaf;

   procedure Close_File (Self : in out Store) is
   begin
      Hostkit.Descriptors.Close (Self.File);
   end Close_File;

   function Open_For_Read (Self : in out Store) return Boolean is
      use Hostkit.Descriptors;
   begin
      Close_File (Self);
      Self.File := Invalid;
      Self.Reading := False;
      Self.Read_Position := 1;

      if not Open_File (Stored_Path (Self), Open_Read, Self.File) then
         return False;
      end if;

      Self.Reading := True;
      return True;
   end Open_For_Read;

   function Skip_To (Self : in out Store; First : Posix_Tools.Numbers.Count) return Boolean is
      use Hostkit.Descriptors;
      Buffer  : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;
      Need    : Posix_Tools.Numbers.Count;
      Got     : Posix_Tools.Numbers.Count;
   begin
      if First < Self.Read_Position and then not Open_For_Read (Self) then
         return False;
      end if;

      while Self.Read_Position < First loop
         Need := First - Self.Read_Position;
         declare
            Read_Last : constant Ada.Streams.Stream_Element_Offset :=
              Buffer'First
              + Ada.Streams.Stream_Element_Offset
                  (Posix_Tools.Numbers.Count'Min
                     (Need, Posix_Tools.Numbers.Count (Buffer'Length)))
              - 1;
         begin
            Outcome := Hostkit.Descriptors.Read (Self.File, Buffer (Buffer'First .. Read_Last), Last);
         end;

         case Outcome is
            when Transfer_Ok =>
               if Last < Buffer'First then
                  return False;
               end if;

               Got := Posix_Tools.Numbers.Count (Last - Buffer'First + 1);
               Self.Read_Position := Self.Read_Position + Got;

            when Transfer_Interrupted =>
               null;

            when others =>
               return False;
         end case;
      end loop;

      return True;
   end Skip_To;

   function Create (Self : in out Store; Max_Bytes : Posix_Tools.Numbers.Count) return Boolean is
      use Hostkit.Descriptors;
   begin
      --  Do not replace the only record of resources that a previous
      --  cleanup could not remove.
      if not Try_Cleanup (Self) then
         return False;
      end if;

      Self.Max_Size := Max_Bytes;
      Self.Current_Size := 0;
      Self.Reading := False;
      Self.Read_Position := 1;

      declare
         Directory : constant String := Hostkit.Fs.Create_Temporary_Directory ("posix-tools-tail");
      begin
         if Directory = "" then
            return False;
         end if;

         --  Record each resource before attempting the next operation so
         --  the exception handler can always retry its removal.
         Self.Directory := U.To_Unbounded_String (Directory);
         declare
            Path : constant String := Hostkit.Fs.Join (Directory, Spill_Leaf (Directory));
         begin
            Self.Path := U.To_Unbounded_String (Path);
            if not Open_File (Path, Open_Write_Exclusive, Self.File) then
               Cleanup (Self);
               return False;
            end if;
         end;
      end;

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
      use Hostkit.Descriptors;
      Amount : Posix_Tools.Numbers.Count;
      From   : Ada.Streams.Stream_Element_Offset := Buffer'First;
      Wrote  : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;
   begin
      if Last < Buffer'First then
         return True;
      end if;

      Amount := Posix_Tools.Numbers.Count (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
      if Amount > Self.Max_Size or else Self.Current_Size > Self.Max_Size - Amount then
         return False;
      end if;

      while From <= Last loop
         Outcome := Hostkit.Descriptors.Write (Self.File, Buffer (From .. Last), Wrote);
         case Outcome is
            when Transfer_Ok =>
               if Wrote < From then
                  return False;
               end if;

               From := Wrote + 1;

            when Transfer_Interrupted =>
               null;

            when others =>
               return False;
         end case;
      end loop;

      Self.Current_Size := Self.Current_Size + Amount;
      return True;
   exception
      when others =>
         return False;
   end Append;

   function Prepare_For_Read (Self : in out Store) return Boolean is
   begin
      return Open_For_Read (Self);
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
      use Hostkit.Descriptors;
      Outcome : Transfer_Outcome;
   begin
      if First = 0 or else First > Self.Current_Size + Posix_Tools.Numbers.Count (1) then
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
      end if;

      if not Self.Reading or else not Skip_To (Self, First) then
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
      end if;

      loop
         Outcome := Hostkit.Descriptors.Read (Self.File, Buffer, Last);
         case Outcome is
            when Transfer_Ok =>
               if Last >= Buffer'First then
                  Self.Read_Position :=
                    Self.Read_Position + Posix_Tools.Numbers.Count (Last - Buffer'First + 1);
               end if;

               return True;

            when Transfer_Interrupted =>
               null;

            when Transfer_End_Of_File =>
               Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
               return True;

            when others =>
               Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
               return False;
         end case;
      end loop;
   exception
      when others =>
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
   end Read;

   function Size (Self : Store) return Posix_Tools.Numbers.Count is
   begin
      return Self.Current_Size;
   end Size;

   function Try_Cleanup (Self : in out Store) return Boolean is
      Path_Remains      : Boolean := False;
      Directory_Remains : Boolean := False;
   begin
      begin
         Close_File (Self);
      exception
         when others =>
            return False;
      end;

      if U.Length (Self.Path) > 0 then
         begin
            if Ada.Directories.Exists (Stored_Path (Self)) then
               Ada.Directories.Delete_File (Stored_Path (Self));
            end if;
         exception
            when others =>
               Path_Remains := True;
         end;
      end if;

      if not Path_Remains and then U.Length (Self.Directory) > 0 then
         begin
            if Ada.Directories.Exists (Stored_Directory (Self)) then
               Ada.Directories.Delete_Directory (Stored_Directory (Self));
            end if;
         exception
            when others =>
               Directory_Remains := True;
         end;
      end if;

      if not Path_Remains then
         Self.Path := U.Null_Unbounded_String;
      end if;
      if not Path_Remains and then not Directory_Remains then
         Self.Directory := U.Null_Unbounded_String;
      end if;
      Self.Current_Size := 0;
      Self.Reading := False;
      Self.Read_Position := 1;
      return not Path_Remains and then not Directory_Remains;
   end Try_Cleanup;

   procedure Cleanup (Self : in out Store) is
      Cleaned : constant Boolean := Try_Cleanup (Self);
      pragma Unreferenced (Cleaned);
   begin
      null;
   end Cleanup;

   overriding procedure Finalize (Self : in out Store) is
   begin
      Cleanup (Self);
   end Finalize;
end Posix_Tools.Host_Adapters.Temporary_Storage;
