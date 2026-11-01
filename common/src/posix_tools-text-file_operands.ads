package Posix_Tools.Text.File_Operands
  with SPARK_Mode => On
is
   --  What a diagnostic calls the file operand File_Name: Standard_Input,
   --  the name of standard input in the messages locale, for "-", else
   --  File_Name itself.
   function Subject_Name (File_Name : String; Standard_Input : String) return String
     with Post =>
       (if File_Name = "-" then
          Subject_Name'Result = Standard_Input
        else
          Subject_Name'Result = File_Name);
end Posix_Tools.Text.File_Operands;
