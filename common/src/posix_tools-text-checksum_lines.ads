package Posix_Tools.Text.Checksum_Lines
  with SPARK_Mode => On
is
   type SHA256_Check_Line is record
      Valid      : Boolean := False;
      Name_First : Natural := 0;
   end record;

   function Lower_Hex (Text : String) return String
     with
       Post =>
         Lower_Hex'Result'Length = Text'Length
         and then Lower_Hex'Result'First = Text'First
         and then Lower_Hex'Result'Last = Text'Last;

   function SHA256_Check_Line_Info (Line : String) return SHA256_Check_Line
     with
       Post =>
         (if SHA256_Check_Line_Info'Result.Valid then
            SHA256_Check_Line_Info'Result.Name_First in Line'Range)
         and then
           (if not SHA256_Check_Line_Info'Result.Valid then
              SHA256_Check_Line_Info'Result.Name_First = 0);
end Posix_Tools.Text.Checksum_Lines;
