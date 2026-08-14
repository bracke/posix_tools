with Posix_Tools.Commands.Expr;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Expr is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("expr", Posix_Tools.Commands.Expr.Run);
begin
   Main;
end Expr;
