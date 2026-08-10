package Posix_Tools.Paths is
   function Basename (Path : String; Suffix : String := "") return String;
   function Dirname (Path : String) return String;
end Posix_Tools.Paths;
