with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Test_Operators
  with SPARK_Mode => On
is
   function Is_Binary_Operator (Op : String) return Boolean is
   begin
      return Op in "=" | "!=" | "<" | ">" | "-ef" | "-eq" | "-ne" | "-gt" | "-ge" | "-lt" | "-le";
   end Is_Binary_Operator;

   function Is_Unary_Operator (Op : String) return Boolean is
   begin
      return Op in "-e" | "-h" | "-L" | "-n" | "-z" | "-d" | "-f" | "-s" | "-t"
        | "-b" | "-c" | "-g" | "-k" | "-p" | "-S" | "-u" | "-r" | "-w" | "-x";
   end Is_Unary_Operator;

   function Numeric_Comparison (Left, Op, Right : String) return Boolean is
      A : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
        Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Left);
      B : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
        Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Right);
   begin
      if not A.Valid or else not B.Valid then
         return False;
      end if;

      return
        (if Op = "-eq" then A.Value = B.Value
         elsif Op = "-ne" then A.Value /= B.Value
         elsif Op = "-gt" then A.Value > B.Value
         elsif Op = "-ge" then A.Value >= B.Value
         elsif Op = "-lt" then A.Value < B.Value
         elsif Op = "-le" then A.Value <= B.Value
         else False);
   end Numeric_Comparison;
end Posix_Tools.Text.Test_Operators;
