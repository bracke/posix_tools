with Posix_Tools.Paths;
with Posix_Tools.Text.Glob;

package body Explore.Paths is
   function Below (Path, Directory : String) return String is
      Prefix : constant String :=
        (if Directory'Length > 0 and then Directory (Directory'Last) = '/' then Directory else Directory & "/");
   begin
      if Path'Length > Prefix'Length and then Path (Path'First .. Path'First + Prefix'Length - 1) = Prefix then
         return Path (Path'First + Prefix'Length .. Path'Last);
      else
         return "";
      end if;
   end Below;

   function Child_Of (Directory, Name : String) return String is
     (if Directory'Length > 0 and then Directory (Directory'Last) = '/'
      then Directory & Name
      else Directory & "/" & Name);

   function Folded (Text : String) return String is
     ([for C of Text => (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C)]);

   function Glob_Matches (Pattern, Name : String) return Boolean is
     (Posix_Tools.Text.Glob.Matches (Folded (Pattern), Folded (Name)));

   function Name_Of (Path : String) return String is
     (if Posix_Tools.Paths.Is_All_Slashes (Path) then ""
      else Posix_Tools.Paths.Basename (Path));

   function Parent_Of (Path : String) return String is
     (if Posix_Tools.Paths.Contains_Slash (Path) then Posix_Tools.Paths.Dirname (Path) else Path);

   function Renamed (Path, Name : String) return String is
   begin
      for I in reverse Path'Range loop
         if Path (I) = '/' then
            return Path (Path'First .. I) & Name;
         end if;
      end loop;

      return Name;
   end Renamed;

   function Resolve (Text, Current, Home : String) return String is
     (if Text = "~" then Home
      elsif Text'Length >= 2 and then Text (Text'First .. Text'First + 1) = "~/"
      then Child_Of (Home, Text (Text'First + 2 .. Text'Last))
      elsif Text (Text'First) = '/' then Text
      else Child_Of (Current, Text));
end Explore.Paths;
