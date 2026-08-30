with Ada.Streams;
with Ada.Strings.Unbounded;
with CryptoLib.Hashes;

with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Checksum_Lines;

package body Posix_Tools.Commands.Sha256sum is
   use Ada.Strings.Unbounded;

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;

   use type Ada.Streams.Stream_Element_Offset;

   function Digest_Image (Digest : CryptoLib.Hashes.SHA256_Digest) return String;

   function Digest_Image (Digest : CryptoLib.Hashes.SHA256_Digest) return String is
      Result : String (1 .. 64);
      Cursor : Positive := Result'First;
   begin
      for Byte of Digest loop
         declare
            Value : constant Natural := Natural (Byte);
         begin
            Result (Cursor) :=
              Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (Value / 16);
            Result (Cursor + 1) :=
              Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (Value mod 16);
            Cursor := Cursor + 2;
         end;
      end loop;

      return Result;
   end Digest_Image;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      All_Ok    : Boolean := True;
      First     : Positive := 1;
      Check_Mode : Boolean := False;

      procedure Check_File (Name : String);

      procedure Emit (Name : String);

      function SHA_256_Of (Name : String; Ok : out Boolean) return String;

      procedure Check_File (Name : String) is
         Data  : Unbounded_String;
         Ok    : Boolean;
         Lines : String_Vectors.Vector;

         procedure Check_Line (Line : String);

         procedure Check_Line (Line : String) is
            Expected  : Unbounded_String;
            File      : Unbounded_String;
            Actual_Ok : Boolean;
            Parsed    : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
              Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Line);
         begin
            if Line = "" then
               return;
            end if;

            if not Parsed.Valid then
               Context.Put_Line (Line & ": improperly formatted SHA256 checksum line");
               All_Ok := False;
               return;
            end if;

            Expected :=
              To_Unbounded_String
                (Posix_Tools.Text.Checksum_Lines.Lower_Hex
                   (Line (Line'First .. Line'First + 63)));
            File := To_Unbounded_String (Line (Parsed.Name_First .. Line'Last));

            declare
               Actual : constant String := SHA_256_Of (To_String (File), Actual_Ok);
            begin
               if not Actual_Ok then
                  Context.Put_Line (To_String (File) & ": FAILED open or read");
                  All_Ok := False;
               elsif Actual = To_String (Expected) then
                  Context.Put_Line (To_String (File) & ": OK");
               else
                  Context.Put_Line (To_String (File) & ": FAILED");
                  All_Ok := False;
               end if;
            end;
         end Check_Line;
      begin
         Posix_Tools.Commands.File_Helpers.Read_All (Context, Name, Data, Ok);
         if not Ok then
            All_Ok := False;
            return;
         end if;

         Lines := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Data));
         for I in 1 .. Natural (Lines.Length) loop
            Check_Line (Lines.Element (I));
            exit when Context.Output_Failed;
         end loop;
      end Check_File;

      procedure Emit (Name : String) is
         Ok     : Boolean;
         Digest : constant String := SHA_256_Of (Name, Ok);
      begin
         if Ok then
            Context.Put_Line (Digest & (if Name = "-" then "" else "  " & Name));
         else
            All_Ok := False;
         end if;
      end Emit;

      function SHA_256_Of (Name : String; Ok : out Boolean) return String is
         Hash_Context : CryptoLib.Hashes.SHA256_Context;

         procedure Hash_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         procedure Hash_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Context);
         begin
            if Last >= Buffer'First then
               CryptoLib.Hashes.Update (Hash_Context, Buffer (Buffer'First .. Last));
            end if;
         end Hash_Chunk;

         procedure Hash_Input is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
           (Action => Hash_Chunk);
      begin
         CryptoLib.Hashes.Initialize_SHA256 (Hash_Context);
         Hash_Input (Context, Name, Ok);
         if Ok then
            return Digest_Image (CryptoLib.Hashes.Finalize (Hash_Context));
         else
            return "";
         end if;
      end SHA_256_Of;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "-c" then
            Check_Mode := True;
            First := First + 1;
         elsif Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         else
            exit;
         end if;
      end loop;

      if Check_Mode then
         if Context.Argument_Count < First then
            Check_File ("-");
         else
            for I in First .. Context.Argument_Count loop
               Check_File (Context.Argument (I));
               exit when Context.Output_Failed;
            end loop;
         end if;
         Result.Status :=
           (if All_Ok and then not Context.Output_Failed
            then Posix_Tools.Exit_Status.Success
            else Posix_Tools.Exit_Status.Operational_Failure);
         return;
      end if;

      if Context.Argument_Count < First then
         Emit ("-");
      else
         for I in First .. Context.Argument_Count loop
            Emit (Context.Argument (I));
         end loop;
      end if;

      Result.Status :=
        (if All_Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Sha256sum;
