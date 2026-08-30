with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Expr_Expressions;

package body Posix_Tools.Commands.Expr is
   use Ada.Strings.Unbounded;

   package Exprs renames Posix_Tools.Text.Expr_Expressions;
   use type Exprs.Evaluation_Status;

   function Diagnostic_Message (Evaluation : Exprs.Evaluation_Result) return String is
      Operand : constant String := To_String (Evaluation.Error_Operand);
   begin
      case Evaluation.Status is
         when Exprs.Valid =>
            return "";
         when Exprs.Missing_Expression =>
            return "missing expression";
         when Exprs.Missing_Operand =>
            return "missing expression operand";
         when Exprs.Missing_Right_Parenthesis =>
            return "missing ')' in expression";
         when Exprs.Unexpected_Right_Parenthesis =>
            return "unexpected ')' in expression";
         when Exprs.Extra_Operand =>
            return "extra operand '" & Operand & "'";
         when Exprs.Non_Numeric_Substr_Operand =>
            return "non-numeric substr operand";
         when Exprs.Invalid_Regular_Expression =>
            return "invalid regular expression '" & Operand & "'";
         when Exprs.Non_Numeric_Arithmetic_Operand =>
            return "non-numeric arithmetic operand";
         when Exprs.Division_By_Zero =>
            return "division by zero";
         when Exprs.Numeric_Overflow =>
            return "numeric overflow";
      end case;
   end Diagnostic_Message;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Arguments  : Posix_Tools.Arguments.Vector;
      Evaluation : Exprs.Evaluation_Result;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         Arguments.Append (Context.Argument (I));
      end loop;

      Evaluation := Exprs.Evaluate (Arguments);
      if Evaluation.Status /= Exprs.Valid then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, Diagnostic_Message (Evaluation));
         return;
      end if;

      Context.Put_Line (To_String (Evaluation.Value));
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         elsif Exprs.Is_False (To_String (Evaluation.Value)) then
            Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Expr;
