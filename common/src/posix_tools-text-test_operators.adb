with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Test_Operators
  with SPARK_Mode => On
is
   function Is_Binary_Operator (Op : String) return Boolean is
   begin
      return Op = "=" or else Op = "!=" or else Op = "<" or else Op = ">"
        or else Op = "-ef" or else Op = "-eq" or else Op = "-ne"
        or else Op = "-gt" or else Op = "-ge" or else Op = "-lt"
        or else Op = "-le";
   end Is_Binary_Operator;

   function Is_Unary_Operator (Op : String) return Boolean is
   begin
      --  Spelled as the postcondition is, so the prover has nothing to relate;
      --  the membership form ran a slow runner's prover out of time.
      return Op = "-e" or else Op = "-h" or else Op = "-L" or else Op = "-n"
        or else Op = "-z" or else Op = "-d" or else Op = "-f"
        or else Op = "-s" or else Op = "-t" or else Op = "-b"
        or else Op = "-c" or else Op = "-g" or else Op = "-k"
        or else Op = "-p" or else Op = "-S" or else Op = "-u"
        or else Op = "-r" or else Op = "-w" or else Op = "-x";
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
