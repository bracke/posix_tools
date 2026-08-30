package Posix_Tools.Text.Test_Operators
  with SPARK_Mode => On
is
   function Is_Binary_Operator (Op : String) return Boolean
     with
       Post =>
         Is_Binary_Operator'Result =
           (Op = "=" or else Op = "!=" or else Op = "<" or else Op = ">"
            or else Op = "-ef" or else Op = "-eq" or else Op = "-ne"
            or else Op = "-gt" or else Op = "-ge" or else Op = "-lt"
            or else Op = "-le");

   function Is_Unary_Operator (Op : String) return Boolean
     with
       Post =>
         Is_Unary_Operator'Result =
           (Op = "-e" or else Op = "-h" or else Op = "-L" or else Op = "-n"
            or else Op = "-z" or else Op = "-d" or else Op = "-f"
            or else Op = "-s" or else Op = "-t" or else Op = "-b"
            or else Op = "-c" or else Op = "-g" or else Op = "-k"
            or else Op = "-p" or else Op = "-S" or else Op = "-u"
            or else Op = "-r" or else Op = "-w" or else Op = "-x");

   function Numeric_Comparison (Left, Op, Right : String) return Boolean
     with
       Pre => Op'First >= 1;
end Posix_Tools.Text.Test_Operators;
