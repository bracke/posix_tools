with Ada.Streams;
with CryptoLib.Hashes;

with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Checksum_Lines;

package body Posix_Tools.Commands.Sha256sum is
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
      Output    : Posix_Tools.Commands.Helpers.Output_Buffer;

      procedure Check_File (Name : String);

      procedure Emit (Name : String);

      function SHA_256_Of (Name : String; Ok : out Boolean) return String;

      procedure Check_File (Name : String) is
         Ok    : Boolean;

         procedure Check_Line (Line : String);
         procedure Take_Line
           (Ignored    : in out Posix_Tools.Commands.Contexts.Context'Class;
            Line       : String;
            Terminated : Boolean);

         procedure Check_Line (Line : String) is
            Actual_Ok : Boolean;
            Parsed    : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
              Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Line);
         begin
            if Line = "" then
               return;
            end if;

            if not Parsed.Valid then
               Posix_Tools.Commands.Helpers.Buffered_Put_Line
                 (Output, Context,
                  Line & ": improperly formatted SHA256 checksum line");
               All_Ok := False;
               return;
            end if;

            declare
               Expected : constant String :=
                 Posix_Tools.Text.Checksum_Lines.Lower_Hex
                   (Line (Line'First .. Line'First + 63));
               File   : constant String := Line (Parsed.Name_First .. Line'Last);
               Actual : constant String := SHA_256_Of (File, Actual_Ok);
            begin
               if not Actual_Ok then
                  Posix_Tools.Commands.Helpers.Buffered_Put_Line
                    (Output, Context, File & ": FAILED open or read");
                  All_Ok := False;
               elsif Actual = Expected then
                  Posix_Tools.Commands.Helpers.Buffered_Put_Line
                    (Output, Context, File & ": OK");
               else
                  Posix_Tools.Commands.Helpers.Buffered_Put_Line
                    (Output, Context, File & ": FAILED");
                  All_Ok := False;
               end if;
            end;
         end Check_Line;

         procedure Take_Line
           (Ignored    : in out Posix_Tools.Commands.Contexts.Context'Class;
            Line       : String;
            Terminated : Boolean)
         is
            pragma Unreferenced (Ignored, Terminated);
         begin
            Check_Line (Line);
         end Take_Line;

         procedure Iterate is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Line
             (Action        => Take_Line,
              Buffer_Length =>
                Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
      begin
         Iterate (Context, Name, Ok);
         if not Ok then
            All_Ok := False;
         end if;
      end Check_File;

      procedure Emit (Name : String) is
         Ok     : Boolean;
         Digest : constant String := SHA_256_Of (Name, Ok);
      begin
         if Ok then
            Posix_Tools.Commands.Helpers.Buffered_Put_Line
              (Output, Context,
               Digest & (if Name = "-" then "" else "  " & Name));
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

         procedure Hash_Input is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
           (Action        => Hash_Chunk,
            Buffer_Length =>
              Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
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
         Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
         Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
         return;
      end if;

      if Context.Argument_Count < First then
         Emit ("-");
      else
         for I in First .. Context.Argument_Count loop
            Emit (Context.Argument (I));
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Sha256sum;
