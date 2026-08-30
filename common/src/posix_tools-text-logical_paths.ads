package Posix_Tools.Text.Logical_Paths
  with SPARK_Mode => On
is
   function Usable_Logical_Path (Path : String) return Boolean
     with
       Post =>
         (if Usable_Logical_Path'Result then
            Path /= "" and then Path (Path'First) = '/');
end Posix_Tools.Text.Logical_Paths;
