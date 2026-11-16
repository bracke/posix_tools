with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Line_Readers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Paste_Delimiters;

package body Posix_Tools.Commands.Paste is
   use Ada.Strings.Unbounded;

   Output_Chunk_Size : constant := 64 * 1024;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First       : Positive;
      Valid       : Boolean;
      Serial      : Boolean := False;
      Delimiters  : Unbounded_String := To_Unbounded_String (Character'Val (9) & "");
      All_Ok      : Boolean := True;

      --  -s, or -d with its delimiter list.
      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Result);
      begin
         if Name = 's' then
            Serial := True;
         else
            Delimiters := To_Unbounded_String (Posix_Tools.Text.Paste_Delimiters.Decode_Delimiters (Value));
         end if;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "ds", "d", First, Valid);
      if not Valid then
         return;
      end if;

      declare
         Count : constant Natural :=
           (if Context.Argument_Count < First then 1 else Context.Argument_Count - First + 1);
         Delimiter_Text : constant String := To_String (Delimiters);

         function Name (Index : Positive) return String is
           (if Context.Argument_Count < First then "-" else Context.Argument (First + Index - 1));

         subtype Paste_Reader is Posix_Tools.Commands.Line_Readers.Reader
           (Posix_Tools.Commands.Line_Readers.Default_Buffer_Length);
         type Reader_Array is array (Positive range <>) of Paste_Reader;

         --  Every "-" operand shares one pull reader, so its records are
         --  handed out in operand order without retaining standard input.
         Readers : Reader_Array (1 .. Count);
         Source  : array (1 .. Count) of Positive;
         Stdin   : Natural := 0;
         Ok      : Boolean := True;
         Opened_Through : Natural := 0;
         Failed_Name : Unbounded_String;
         Pending : Unbounded_String;

         procedure Flush;
         procedure Put (Text : String);
         procedure Put (Text : Unbounded_String);

         procedure Flush is
         begin
            if Length (Pending) > 0 and then not Context.Output_Failed then
               Context.Put (To_String (Pending));
            end if;
            Pending := Null_Unbounded_String;
         end Flush;

         procedure Put (Text : String) is
         begin
            Append (Pending, Text);
            if Length (Pending) >= Output_Chunk_Size then
               Flush;
            end if;
         end Put;

         procedure Put (Text : Unbounded_String) is
            First : Positive := 1;
         begin
            if Length (Text) < Output_Chunk_Size then
               Append (Pending, Text);
               if Length (Pending) >= Output_Chunk_Size then
                  Flush;
               end if;
               return;
            end if;

            Flush;
            while First <= Length (Text) and then not Context.Output_Failed loop
               declare
                  Last : constant Natural :=
                    Natural'Min (Length (Text), First + Output_Chunk_Size - 1);
               begin
                  Context.Put (Slice (Text, First, Last));
                  First := Last + 1;
               end;
            end loop;
         end Put;

         --  Take Source (Index)'s next line into Line; False past its end.
         function Take (Index : Positive; Line : out Unbounded_String) return Boolean is
            S : constant Positive := Source (Index);
            Available : Boolean;
            Read_Ok   : Boolean;
         begin
            Posix_Tools.Commands.Line_Readers.Next
              (Readers (S), Context, Line, Available, Read_Ok);
            Ok := Ok and Read_Ok;
            return Available;
         end Take;
      begin
         for I in 1 .. Count loop
            if Name (I) = "-" and then Stdin /= 0 then
               Source (I) := Stdin;
            else
               Failed_Name := To_Unbounded_String (Name (I));
               Posix_Tools.Commands.Line_Readers.Open (Readers (I), Name (I), Ok);
               exit when not Ok;
               Source (I) := I;
               Opened_Through := I;
               if Name (I) = "-" then
                  Stdin := I;
               end if;
            end if;
         end loop;
         if not Ok then
            for I in 1 .. Opened_Through loop
               if Source (I) = I then
                  declare
                     Closed : Boolean;
                  begin
                     Posix_Tools.Commands.Line_Readers.Close (Readers (I), Closed);
                  end;
               end if;
            end loop;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Failed_Name),
               "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         if Serial then
            for File_Index in 1 .. Count loop
               declare
                  Line   : Unbounded_String;
                  Row    : Natural := 0;
               begin
                  while Take (File_Index, Line) loop
                     Row := Row + 1;
                     if Row > 1 then
                        Put
                          (Posix_Tools.Text.Paste_Delimiters.Delimiter
                             (Delimiter_Text, Row - 1));
                     end if;
                     Put (Line);
                     exit when Context.Output_Failed;
                  end loop;
                  if Row > 0 and then not Context.Output_Failed then
                     Put ([1 => Character'Val (10)]);
                     exit when Context.Output_Failed;
                  end if;
               end;
            end loop;
         else
            declare
               type Line_Array is array (Positive range <>) of Unbounded_String;
               Lines   : Line_Array (1 .. Count);
               Present : array (1 .. Count) of Boolean;
            begin
               loop
                  declare
                     Any : Boolean := False;
                  begin
                     for File_Index in 1 .. Count loop
                        Present (File_Index) :=
                          Take (File_Index, Lines (File_Index));
                        if Present (File_Index) then
                           Any := True;
                        end if;
                     end loop;
                     exit when not Any;
                     for File_Index in 1 .. Count loop
                        if File_Index > 1 then
                           Put
                             (Posix_Tools.Text.Paste_Delimiters.Delimiter
                                (Delimiter_Text, File_Index - 1));
                        end if;
                        if Present (File_Index) then
                           Put (Lines (File_Index));
                        end if;
                     end loop;
                     Put ([1 => Character'Val (10)]);
                     exit when Context.Output_Failed;
                  end;
               end loop;
            end;
         end if;

         Flush;

         for I in Readers'Range loop
            if Source (I) = I then
               declare
                  Closed : Boolean;
               begin
                  Posix_Tools.Commands.Line_Readers.Close (Readers (I), Closed);
                  Ok := Ok and Closed;
               end;
            end if;
         end loop;
         if not Ok and then not Context.Output_Failed then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
         end if;
         All_Ok := Ok;
      end;
      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Paste;
