with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Paste_Delimiters;

package body Posix_Tools.Commands.Paste is
   use Ada.Strings.Unbounded;

   package String_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Line_Vector_Array is array (Positive range <>) of String_Vectors.Vector;
      First       : Positive;
      Valid       : Boolean;
      Serial      : Boolean := False;
      Delimiters  : Unbounded_String := To_Unbounded_String (Character'Val (9) & "");

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

         function Name (Index : Positive) return String is
           (if Context.Argument_Count < First then "-" else Context.Argument (First + Index - 1));

         --  Every "-" operand reads from the one standard input: its lines
         --  are kept once, in Files (Stdin), and handed out in turn.
         Files   : Line_Vector_Array (1 .. Count);
         Source  : array (1 .. Count) of Positive;
         Next    : array (1 .. Count) of Positive := [others => 1];
         Stdin   : Natural := 0;
         Ok      : Boolean := True;

         --  Take Source (Index)'s next line into Line; False past its end.
         function Take (Index : Positive; Line : out Unbounded_String) return Boolean is
            S : constant Positive := Source (Index);
         begin
            if Next (S) > Natural (Files (S).Length) then
               Line := Null_Unbounded_String;
               return False;
            end if;
            Line := To_Unbounded_String (Files (S).Element (Next (S)));
            Next (S) := Next (S) + 1;
            return True;
         end Take;
      begin
         for I in 1 .. Count loop
            if Name (I) = "-" and then Stdin /= 0 then
               Source (I) := Stdin;
            else
               declare
                  Data : Unbounded_String;
               begin
                  Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Name (I), Data, Ok);
                  exit when not Ok;
                  Files (I) := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Data));
                  Source (I) := I;
                  if Name (I) = "-" then
                     Stdin := I;
                  end if;
               end;
            end if;
         end loop;
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         if Serial then
            for File_Index in 1 .. Count loop
               declare
                  Output : Unbounded_String;
                  Line   : Unbounded_String;
                  Row    : Natural := 0;
               begin
                  while Take (File_Index, Line) loop
                     Row := Row + 1;
                     if Row > 1 then
                        Append
                          (Output,
                           Posix_Tools.Text.Paste_Delimiters.Delimiter
                             (To_String (Delimiters), Row - 1));
                     end if;
                     Append (Output, Line);
                  end loop;
                  if Row > 0 then
                     Context.Put_Line (To_String (Output));
                     exit when Context.Output_Failed;
                  end if;
               end;
            end loop;
         else
            loop
               declare
                  Output : Unbounded_String;
                  Line   : Unbounded_String;
                  Any    : Boolean := False;
               begin
                  for File_Index in 1 .. Count loop
                     if File_Index > 1 then
                        Append
                          (Output,
                           Posix_Tools.Text.Paste_Delimiters.Delimiter
                             (To_String (Delimiters), File_Index - 1));
                     end if;
                     if Take (File_Index, Line) then
                        Any := True;
                        Append (Output, Line);
                     end if;
                  end loop;
                  exit when not Any;
                  Context.Put_Line (To_String (Output));
                  exit when Context.Output_Failed;
               end;
            end loop;
         end if;
      end;
      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;
end Posix_Tools.Commands.Paste;
