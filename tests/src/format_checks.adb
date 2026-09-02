with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Posix_Tools.Text.Matching;
with Project_Tools.Files;
with Project_Tools.Release_Checks;

package body Format_Checks is
   function Is_Checked_Text_File (Path : String) return Boolean is
   begin
      return Posix_Tools.Text.Matching.Ends_With (Path, ".adb")
        or else Posix_Tools.Text.Matching.Ends_With (Path, ".ads")
        or else Posix_Tools.Text.Matching.Ends_With (Path, ".gpr")
        or else Posix_Tools.Text.Matching.Ends_With (Path, ".toml")
        or else Posix_Tools.Text.Matching.Ends_With (Path, ".md")
        or else Posix_Tools.Text.Matching.Ends_With (Path, ".csv")
        or else Posix_Tools.Text.Matching.Ends_With (Path, ".txt");
   end Is_Checked_Text_File;

   function Has_Tab (Text : String) return Boolean is
   begin
      for Ch of Text loop
         if Ch = Character'Val (9) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Tab;

   function Has_Trailing_Whitespace (Text : String) return Boolean is
      Line_Last : Natural := 0;
   begin
      for I in Text'Range loop
         if Text (I) = Character'Val (10) then
            declare
               Last : Natural := I - 1;
            begin
               if Last >= Text'First and then Text (Last) = Character'Val (13) then
                  Last := Last - 1;
               end if;

               if Last >= Text'First
                 and then Last >= Line_Last
                 and then (Text (Last) = ' ' or else Text (Last) = Character'Val (9))
               then
                  return True;
               end if;
            end;
            Line_Last := I + 1;
         end if;
      end loop;

      return Text'Length > 0
        and then (Text (Text'Last) = ' ' or else Text (Text'Last) = Character'Val (9));
   end Has_Trailing_Whitespace;

   function Has_Multiple_Blank_Lines (Text : String) return Boolean is
      Previous_Blank : Boolean := False;
      Line_Has_Text  : Boolean := False;
   begin
      for Ch of Text loop
         if Ch = Character'Val (10) then
            if not Line_Has_Text then
               if Previous_Blank then
                  return True;
               end if;
               Previous_Blank := True;
            else
               Previous_Blank := False;
            end if;

            Line_Has_Text := False;
         elsif Ch /= Character'Val (13) then
            Line_Has_Text := True;
         end if;
      end loop;

      return False;
   end Has_Multiple_Blank_Lines;

   procedure Run (Root : String) is
      use Ada.Strings.Unbounded;
      Files : constant Project_Tools.Files.Path_List :=
        Project_Tools.Files.List_Tree
          (Root,
           Skip_Entries =>
             [To_Unbounded_String ("alire"),
              To_Unbounded_String ("bin"),
              To_Unbounded_String ("config"),
              To_Unbounded_String ("fixtures"),
              To_Unbounded_String ("lib"),
              To_Unbounded_String ("obj")]);
   begin
      for Path of Files loop
         declare
            File_Path : constant String := To_String (Path);
         begin
            if Is_Checked_Text_File (File_Path) then
               declare
                  Content : constant String := Project_Tools.Files.Read_Raw_File (File_Path);
               begin
                  if Has_Tab (Content) then
                     Project_Tools.Release_Checks.Fail ("tab character in " & File_Path);
                  elsif Has_Trailing_Whitespace (Content) then
                     Project_Tools.Release_Checks.Fail ("trailing whitespace in " & File_Path);
                  elsif Has_Multiple_Blank_Lines (Content) then
                     Project_Tools.Release_Checks.Fail ("multiple consecutive blank lines in " & File_Path);
                  end if;
               end;
            end if;
         end;
      end loop;

      Ada.Text_IO.Put_Line ("format checks passed");
   end Run;
end Format_Checks;
