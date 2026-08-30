with Posix_Tools.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

package Posix_Tools.Commands.Find_Validation is
   function Validate_Expression
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result     : out Posix_Tools.Commands.Results.Result;
      Expression : Posix_Tools.Arguments.Vector) return Boolean;
end Posix_Tools.Commands.Find_Validation;
