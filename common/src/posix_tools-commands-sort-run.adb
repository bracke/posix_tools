separate (Posix_Tools.Commands.Sort)
procedure Run
  (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
   Result  : out Posix_Tools.Commands.Results.Result)
is
   Options : Run_Options;
   Ok      : Boolean := True;

   procedure Sort_And_Write is separate;
begin
   if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
      return;
   elsif not Parse_Options (Context, Result, Options) then
      return;
   end if;

   Sort_And_Write;

   Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
end Run;
