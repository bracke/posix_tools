package body Posix_Tools.Text.File_Operands
  with SPARK_Mode => On
is
   function Subject_Name (File_Name : String; Standard_Input : String) return String is
   begin
      if File_Name = "-" then
         return Standard_Input;
      end if;

      return File_Name;
   end Subject_Name;
end Posix_Tools.Text.File_Operands;
