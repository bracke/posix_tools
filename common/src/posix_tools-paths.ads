package Posix_Tools.Paths
  with SPARK_Mode => On
is
   function Is_All_Slashes (Path : String) return Boolean is
     (Path /= "" and then (for all I in Path'Range => Path (I) = '/'));

   function Contains_Slash (Path : String) return Boolean is
     (for some I in Path'Range => Path (I) = '/');

   function Basename (Path : String; Suffix : String := "") return String
     with
       Post =>
         (if Path = "" then Basename'Result = "")
         and then (if Path /= "" then Basename'Result /= "")
         and then (if Is_All_Slashes (Path) then Basename'Result = "/")
         and then
           (if Path /= ""
             and then not Contains_Slash (Path)
             and then
               (Suffix = ""
                or else Path'Length <= Suffix'Length
                or else Path (Path'Last - Suffix'Length + 1 .. Path'Last) /= Suffix)
            then
              Basename'Result = Path);

   function Dirname (Path : String) return String
     with
       Post =>
         Dirname'Result /= ""
         and then (if Path = "" then Dirname'Result = ".")
         and then (if Is_All_Slashes (Path) then Dirname'Result = "/")
         and then
           (if Path'Length = 1 and then Path /= "" and then Path (Path'First) /= '/' then
              Dirname'Result = ".");
end Posix_Tools.Paths;
