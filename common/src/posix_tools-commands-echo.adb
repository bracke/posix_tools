with Posix_Tools.Commands.Helpers;

package body Posix_Tools.Commands.Echo is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension
        (Context, Result, Conventional => False)
      then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if I > 1 then
            Context.Put (" ");
         end if;

         Context.Put (Context.Argument (I));
      end loop;

      Context.Put ("" & Character'Val (10));
      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;
end Posix_Tools.Commands.Echo;
