package body Posix_Tools.Paths is
   function Collapse_Leading_Root (Path : String) return String is
      First_Non_Slash : Natural := Path'First;
   begin
      if Path'Length < 2 or else Path (Path'First) /= '/' or else Path (Path'First + 1) /= '/' then
         return Path;
      end if;

      while First_Non_Slash <= Path'Last and then Path (First_Non_Slash) = '/' loop
         First_Non_Slash := First_Non_Slash + 1;
      end loop;

      if First_Non_Slash > Path'Last then
         return "/";
      end if;

      return "/" & Path (First_Non_Slash .. Path'Last);
   end Collapse_Leading_Root;

   function Trim_Trailing_Slashes (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last >= Path'First and then Path (Last) = '/' loop
         Last := Last - 1;
      end loop;

      if Last < Path'First then
         return "/";
      end if;

      return Path (Path'First .. Last);
   end Trim_Trailing_Slashes;

   function Basename (Path : String; Suffix : String := "") return String is
      Trimmed : constant String := (if Path = "" then "" else Trim_Trailing_Slashes (Path));
      Start   : Positive := Trimmed'First;
      Base    : Natural;
   begin
      if Path = "" then
         return "";
      elsif Trimmed = "/" then
         return "/";
      end if;

      Base := Trimmed'Last;
      while Base >= Trimmed'First and then Trimmed (Base) /= '/' loop
         Base := Base - 1;
      end loop;

      if Base < Trimmed'First then
         Start := Trimmed'First;
      else
         Start := Base + 1;
      end if;

      declare
         Name : constant String := Trimmed (Start .. Trimmed'Last);
      begin
         if Suffix /= ""
           and then Name'Length > Suffix'Length
           and then Name (Name'Last - Suffix'Length + 1 .. Name'Last) = Suffix
         then
            return Name (Name'First .. Name'Last - Suffix'Length);
         end if;

         return Name;
      end;
   end Basename;

   function Dirname (Path : String) return String is
      Trimmed : constant String := (if Path = "" then "" else Trim_Trailing_Slashes (Path));
      Last_Slash : Natural := 0;
   begin
      if Path = "" then
         return ".";
      elsif Trimmed = "/" then
         return "/";
      end if;

      for I in reverse Trimmed'Range loop
         if Trimmed (I) = '/' then
            Last_Slash := I;
            exit;
         end if;
      end loop;

      if Last_Slash = 0 then
         return ".";
      end if;

      while Last_Slash > Trimmed'First and then Trimmed (Last_Slash) = '/' loop
         Last_Slash := Last_Slash - 1;
      end loop;

      if Last_Slash < Trimmed'First then
         return "/";
      end if;

      return Collapse_Leading_Root (Trimmed (Trimmed'First .. Last_Slash));
   end Dirname;
end Posix_Tools.Paths;
