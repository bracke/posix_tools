package body Posix_Tools.Paths
  with SPARK_Mode => On
is
   function Apply_Suffix (Name : String; Suffix : String) return String
     with
       Pre  => Name /= "",
       Post =>
         Apply_Suffix'Result /= ""
       and then
         (if Suffix = ""
           or else Name'Length <= Suffix'Length
           or else Name (Name'Last - Suffix'Length + 1 .. Name'Last) /= Suffix
          then
            Apply_Suffix'Result = Name);

   function Apply_Suffix (Name : String; Suffix : String) return String is
   begin
      if Suffix /= ""
        and then Name'Length > Suffix'Length
        and then Name (Name'Last - Suffix'Length + 1 .. Name'Last) = Suffix
      then
         return Name (Name'First .. Name'Last - Suffix'Length);
      end if;

      return Name;
   end Apply_Suffix;

   function Collapse_Leading_Root (Path : String) return String
     with
       Pre  => Path /= "",
       Post => Collapse_Leading_Root'Result /= ""
   is
      First_Non_Slash : Positive := Path'First;
   begin
      if Path'Length < 2 or else Path (Path'First) /= '/' or else Path (Path'First + 1) /= '/' then
         return Path;
      end if;

      while First_Non_Slash <= Path'Last and then Path (First_Non_Slash) = '/' loop
         pragma Loop_Invariant (First_Non_Slash in Path'Range);
         pragma Loop_Variant (Increases => First_Non_Slash);
         if First_Non_Slash = Path'Last then
            return "/";
         end if;
         First_Non_Slash := First_Non_Slash + 1;
      end loop;

      return "/" & Path (First_Non_Slash .. Path'Last);
   end Collapse_Leading_Root;

   function Trim_Trailing_Slashes (Path : String) return String
     with
       Pre  => Path /= "",
       Post =>
         Trim_Trailing_Slashes'Result /= ""
         and then (if Is_All_Slashes (Path) then Trim_Trailing_Slashes'Result = "/")
         and then
           (if Path (Path'Last) /= '/' then
              Trim_Trailing_Slashes'Result = Path)
         and then
           (if Trim_Trailing_Slashes'Result /= "/" then
              Trim_Trailing_Slashes'Result (Trim_Trailing_Slashes'Result'Last) /= '/')
   is
      Last : Positive := Path'Last;
   begin
      while Path (Last) = '/' loop
         pragma Loop_Invariant (Last in Path'Range);
         pragma Loop_Variant (Decreases => Last);
         if Last = Path'First then
            return "/";
         end if;
         pragma Assert (Last > Positive'First);
         Last := Last - 1;
      end loop;

      return Path (Path'First .. Last);
   end Trim_Trailing_Slashes;

   function Basename (Path : String; Suffix : String := "") return String is
   begin
      if Path = "" then
         return "";
      elsif Path = "/" then
         return "/";
      end if;

      declare
         Trimmed : constant String := Trim_Trailing_Slashes (Path);
         Start   : Positive;
         Base    : Positive;
      begin
         if Trimmed = "/" then
            return "/";
         end if;

         pragma Assert (Trimmed /= "");
         Base := Trimmed'Last;
         while Base >= Trimmed'First and then Trimmed (Base) /= '/' loop
            pragma Loop_Invariant (Base in Trimmed'Range);
            pragma Loop_Variant (Decreases => Base);
            if Base = Trimmed'First then
               if not Contains_Slash (Path)
                 and then
                   (Suffix = ""
                    or else Path'Length <= Suffix'Length
                    or else Path (Path'Last - Suffix'Length + 1 .. Path'Last) /= Suffix)
               then
                  pragma Assert (Trimmed = Path);
                  return Path;
               end if;

               return Apply_Suffix (Trimmed, Suffix);
            end if;
            Base := Base - 1;
         end loop;

         pragma Assert (Base in Trimmed'Range);
         pragma Assert (Trimmed (Base) = '/');
         pragma Assert (Trimmed (Trimmed'Last) /= '/');
         pragma Assert (Base < Trimmed'Last);
         Start := Base + 1;

         declare
            Name : constant String := Trimmed (Start .. Trimmed'Last);
         begin
            return Apply_Suffix (Name, Suffix);
         end;
      end;
   end Basename;

   function Dirname (Path : String) return String is
   begin
      if Path = "" then
         return ".";
      elsif Path = "/" then
         return "/";
      elsif Path'Length = 1 and then Path (Path'First) /= '/' then
         return ".";
      end if;

      declare
         Trimmed    : constant String := Trim_Trailing_Slashes (Path);
         Last_Slash : Natural := 0;
      begin
         if Trimmed = "/" then
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

         pragma Assert (Last_Slash in Trimmed'Range);
         while Last_Slash > Trimmed'First and then Trimmed (Last_Slash) = '/' loop
            pragma Loop_Invariant (Last_Slash in Trimmed'Range);
            pragma Loop_Variant (Decreases => Last_Slash);
            Last_Slash := Last_Slash - 1;
         end loop;

         if Last_Slash < Trimmed'First then
            return "/";
         end if;

         return Collapse_Leading_Root (Trimmed (Trimmed'First .. Last_Slash));
      end;
   end Dirname;
end Posix_Tools.Paths;
