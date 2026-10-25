with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Expr_Expressions;

package body Posix_Tools.Commands.Expr is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   subtype Usage_Message is Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   package Exprs renames Posix_Tools.Text.Expr_Expressions;
   use type Exprs.Evaluation_Status;

   --  The usage diagnostic for an expression that did not evaluate.
   function Diagnostic (Status : Exprs.Evaluation_Status) return Usage_Message is
     (case Status is
         when Exprs.Valid | Exprs.Missing_Expression => Missing_Expression,
         when Exprs.Missing_Operand => Missing_Expression_Operand,
         when Exprs.Missing_Right_Parenthesis => Missing_Right_Parenthesis,
         when Exprs.Unexpected_Right_Parenthesis => Unexpected_Right_Parenthesis,
         when Exprs.Extra_Operand => Extra_Operand,
         when Exprs.Non_Numeric_Substr_Operand => Non_Numeric_Substr_Operand,
         when Exprs.Invalid_Regular_Expression => Invalid_Regular_Expression,
         when Exprs.Non_Numeric_Arithmetic_Operand => Non_Numeric_Arithmetic_Operand,
         when Exprs.Division_By_Zero => Division_By_Zero,
         when Exprs.Numeric_Overflow => Numeric_Overflow);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Arguments  : Posix_Tools.Arguments.Vector;
      Evaluation : Exprs.Evaluation_Result;
   begin
      --  Every argument is an operand of the expression, so the project
      --  extensions are recognized only as a sole argument.
      if Posix_Tools.Commands.Helpers.Intercept_Extension
        (Context, Result, Conventional => False)
      then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         Arguments.Append (Context.Argument (I));
      end loop;

      Evaluation := Exprs.Evaluate (Arguments);
      if Evaluation.Status /= Exprs.Valid then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, Diagnostic (Evaluation.Status), To_String (Evaluation.Error_Operand));
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
