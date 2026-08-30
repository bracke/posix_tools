package Posix_Tools.Text.File_Magic_Fields
  with SPARK_Mode => On
is
   type Magic_Field is record
      Last : Natural := 0;
      Next : Positive := 1;
      At_End : Boolean := True;
   end record;

   function Next_Field (Line : String; From : Positive) return Magic_Field
     with Pre => Line /= "" and then From in Line'Range;
end Posix_Tools.Text.File_Magic_Fields;
