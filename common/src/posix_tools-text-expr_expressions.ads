with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;

package Posix_Tools.Text.Expr_Expressions is
   type Evaluation_Status is
     (Valid,
      Missing_Expression,
      Missing_Operand,
      Missing_Right_Parenthesis,
      Unexpected_Right_Parenthesis,
      Extra_Operand,
      Non_Numeric_Substr_Operand,
      Invalid_Regular_Expression,
      Non_Numeric_Arithmetic_Operand,
      Division_By_Zero,
      Numeric_Overflow);

   type Evaluation_Result is record
      Status       : Evaluation_Status := Valid;
      Value        : Ada.Strings.Unbounded.Unbounded_String;
      Error_Operand : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Evaluate (Arguments : Posix_Tools.Arguments.Vector) return Evaluation_Result;

   function Is_False (Value : String) return Boolean is
     (Value = "" or else Value = "0");
end Posix_Tools.Text.Expr_Expressions;
