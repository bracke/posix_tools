with Posix_Tools.Commands.Locale;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Locale is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("locale", Posix_Tools.Commands.Locale.Run);
begin
   Main;
end Locale;
