with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
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
      First       : Positive := 1;
      Serial      : Boolean := False;
      Delimiters  : Unbounded_String := To_Unbounded_String (Character'Val (9) & "");
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg = "-s" then
               Serial := True;
               First := First + 1;
            elsif Arg = "-d" then
               if First >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '-d'");
                  return;
               end if;
               Delimiters :=
                 To_Unbounded_String
                   (Posix_Tools.Text.Paste_Delimiters.Decode_Delimiters
                      (Context.Argument (First + 1)));
               First := First + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 'd'
            then
               Delimiters :=
                 To_Unbounded_String
                   (Posix_Tools.Text.Paste_Delimiters.Decode_Delimiters
                      (Arg (Arg'First + 2 .. Arg'Last)));
               First := First + 1;
            else
               exit;
            end if;
         end;
      end loop;

      declare
         Count : constant Natural :=
           (if Context.Argument_Count < First then 1 else Context.Argument_Count - First + 1);
         Files : Line_Vector_Array (1 .. Count);
         Max   : Natural := 0;
         Ok    : Boolean := True;
      begin
         for I in 1 .. Count loop
            declare
               Data : Unbounded_String;
               Name : constant String :=
                 (if Context.Argument_Count < First then "-" else Context.Argument (First + I - 1));
            begin
               Posix_Tools.Commands.File_Helpers.Read_All (Context, Name, Data, Ok);
               exit when not Ok;
               Files (I) := Posix_Tools.Streams.Lines.Split_LF_Records (To_String (Data));
               Max := Natural'Max (Max, Natural (Files (I).Length));
            end;
         end loop;
         if not Ok then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         if Serial then
            for File_Index in 1 .. Count loop
               declare
                  Output : Unbounded_String;
               begin
                  for Row in 1 .. Natural (Files (File_Index).Length) loop
                     if Row > 1 then
                        Append
                          (Output,
                           Posix_Tools.Text.Paste_Delimiters.Delimiter
                             (To_String (Delimiters), Row - 1));
                     end if;
                     Append (Output, Files (File_Index).Element (Row));
                  end loop;
                  if Natural (Files (File_Index).Length) > 0 then
                     Context.Put_Line (To_String (Output));
                     exit when Context.Output_Failed;
                  end if;
               end;
            end loop;
         else
            for Row in 1 .. Max loop
               declare
                  Output : Unbounded_String;
               begin
                  for File_Index in 1 .. Count loop
                     if File_Index > 1 then
                        Append
                          (Output,
                           Posix_Tools.Text.Paste_Delimiters.Delimiter
                             (To_String (Delimiters), File_Index - 1));
                     end if;
                     if Row <= Natural (Files (File_Index).Length) then
                        Append (Output, Files (File_Index).Element (Row));
                     end if;
                  end loop;
                  Context.Put_Line (To_String (Output));
                  if Context.Output_Failed then
                     exit;
                  end if;
               end;
            end loop;
         end if;
      end;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Paste;
