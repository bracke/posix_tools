package Posix_Tools.Text.File_Operands
  with SPARK_Mode => On
is
   function Subject_Name (File_Name : String) return String
     with Post =>
       (if File_Name = "-" then
          Subject_Name'Result = "standard input"
        else
          Subject_Name'Result = File_Name);
end Posix_Tools.Text.File_Operands;
