with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Version;
with Project_Tools.Files;
with Tooling_Support;

package body Metadata_Checks is
   use Tooling_Support;

   function Check return Project_Tools.Release_Checks.Checker is
   begin
      return Project_Tools.Release_Checks.Create (Root);
   end Check;

   function Count_Exact_Lines (Text : String; Expected : String) return Natural is
      Start : Positive := Text'First;
      Count : Natural := 0;
   begin
      if Text = "" then
         return 0;
      end if;

      for I in Text'Range loop
         if Text (I) = Character'Val (10) then
            if I > Start
              and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                (Text (Start .. I - 1)) = Expected
            then
               Count := Count + 1;
            end if;

            Start := I + 1;
         end if;
      end loop;

      if Start <= Text'Last
        and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
          (Text (Start .. Text'Last)) = Expected
      then
         Count := Count + 1;
      end if;

      return Count;
   end Count_Exact_Lines;

   procedure Forbid_Text (Path : String; Text : String; Message : String) is
   begin
      if Project_Tools.Files.File_Contains (Project_Tools.Files.Join (Root, Path), Text) then
         Project_Tools.Release_Checks.Fail (Message);
      end if;
   end Forbid_Text;

   procedure Require_Crate_Metadata
     (Path         : String;
      Name         : String;
      Project_File : String) is
   begin
      Project_Tools.Release_Checks.Require_Text (Check, Path, "name = """ & Name & """");
      Require_Synchronized_Version (Path);
      Project_Tools.Release_Checks.Require_Text (Check, Path, "authors =");
      Project_Tools.Release_Checks.Require_Text (Check, Path, "maintainers =");
      Project_Tools.Release_Checks.Require_Text (Check, Path, "maintainers-logins =");
      Project_Tools.Release_Checks.Require_Text (Check, Path, "licenses = ""MIT""");
      Project_Tools.Release_Checks.Require_Text (Check, Path, "project-files = [""" & Project_File & """]");
      Project_Tools.Release_Checks.Require_Text (Check, Path, "[build-profiles]");
      Project_Tools.Release_Checks.Require_Text (Check, Path, """*"" = ""development""");
   end Require_Crate_Metadata;

   procedure Require_Exact_Line (Path : String; Line : String; Description : String) is
      Content : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
      Count   : constant Natural := Count_Exact_Lines (Content, Line);
   begin
      if Count = 0 then
         Project_Tools.Release_Checks.Fail (Description & " missing or stale in " & Path);
      elsif Count > 1 then
         Project_Tools.Release_Checks.Fail (Description & " duplicated in " & Path);
      end if;
   end Require_Exact_Line;

   procedure Require_Synchronized_Version (Path : String) is
   begin
      Project_Tools.Release_Checks.Require_Text
        (Check, Path, Posix_Tools.Version.Version_String);
   end Require_Synchronized_Version;
end Metadata_Checks;
