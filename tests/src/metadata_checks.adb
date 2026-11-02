with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Version;
with Project_Tools.Files;
with Tooling_Support;

package body Metadata_Checks is
   use Tooling_Support;

   function Check return Tooling_Checks.Checker is
   begin
      return Tooling_Checks.Create (Root);
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
         Tooling_Checks.Fail (Message);
      end if;
   end Forbid_Text;

   procedure Require_Crate_Metadata
     (Path         : String;
      Name         : String;
      Project_File : String) is
   begin
      Tooling_Checks.Require_Text (Check, Path, "name = """ & Name & """");
      Require_Synchronized_Version (Path);
      Tooling_Checks.Require_Text (Check, Path, "authors =");
      Tooling_Checks.Require_Text (Check, Path, "maintainers =");
      Tooling_Checks.Require_Text (Check, Path, "maintainers-logins =");
      Tooling_Checks.Require_Text (Check, Path, "licenses = ""MIT""");
      Tooling_Checks.Require_Text (Check, Path, "project-files = [""" & Project_File & """]");
      Tooling_Checks.Require_Text (Check, Path, "[build-profiles]");
      Tooling_Checks.Require_Text (Check, Path, """*"" = ""development""");
   end Require_Crate_Metadata;

   procedure Require_Exact_Line (Path : String; Line : String; Description : String) is
      Content : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
      Count   : constant Natural := Count_Exact_Lines (Content, Line);
   begin
      if Count = 0 then
         Tooling_Checks.Fail (Description & " missing or stale in " & Path);
      elsif Count > 1 then
         Tooling_Checks.Fail (Description & " duplicated in " & Path);
      end if;
   end Require_Exact_Line;

   procedure Require_Line_Order (Path : String; Earlier : String; Later : String) is
      Content      : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
      Line_Number  : Natural := 0;
      Last_Earlier : Natural := 0;
      First_Later  : Natural := 0;
      Start        : Positive := Content'First;
   begin
      for I in Content'Range loop
         if Content (I) = Character'Val (10) or else I = Content'Last then
            declare
               Line : constant String :=
                 Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Content (Start .. (if Content (I) = Character'Val (10) then I - 1 else I)));
            begin
               Line_Number := Line_Number + 1;
               if Line = Earlier then
                  Last_Earlier := Line_Number;
               elsif Line = Later and then First_Later = 0 then
                  First_Later := Line_Number;
               end if;
            end;
            Start := I + 1;
         end if;
      end loop;

      if Last_Earlier = 0 then
         Tooling_Checks.Fail (Path & " is missing the line: " & Earlier);
      elsif First_Later = 0 then
         Tooling_Checks.Fail (Path & " is missing the line: " & Later);
      elsif Last_Earlier > First_Later then
         Tooling_Checks.Fail (Path & " must run """ & Earlier & """ before """ & Later & """");
      end if;
   end Require_Line_Order;

   procedure Require_Synchronized_Version (Path : String) is
   begin
      Tooling_Checks.Require_Text
        (Check, Path, Posix_Tools.Version.Version_String);
   end Require_Synchronized_Version;
end Metadata_Checks;
