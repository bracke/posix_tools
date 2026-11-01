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
      Last : Natural := Path'Last;
   begin
      while Last >= Path'First and then Path (Last) = '/' loop
         Last := Last - 1;
      end loop;

      for I in reverse Path'First .. Last loop
         if Path (I) = '/' then
            return Path (I + 1 .. Last);
         end if;
      end loop;

      return Path (Path'First .. Last);
   end Name_Of;

   function Parent_Of (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last > Path'First and then Path (Last) = '/' loop
         Last := Last - 1;
      end loop;

      for I in reverse Path'First .. Last loop
         if Path (I) = '/' then
            return (if I = Path'First then "/" else Path (Path'First .. I - 1));
         end if;
      end loop;

      return Path;
   end Parent_Of;

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
