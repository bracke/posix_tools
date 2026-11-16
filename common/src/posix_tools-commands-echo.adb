with Posix_Tools.Commands.Helpers;

package body Posix_Tools.Commands.Echo is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Output : Posix_Tools.Commands.Helpers.Output_Buffer;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension
        (Context, Result, Conventional => False)
      then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if I > 1 then
            Posix_Tools.Commands.Helpers.Buffered_Put
              (Output, Context, " ");
         end if;

         Posix_Tools.Commands.Helpers.Buffered_Put
           (Output, Context, Context.Argument (I));
      end loop;

      Posix_Tools.Commands.Helpers.Buffered_Put
        (Output, Context, "" & Character'Val (10));
      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;
end Posix_Tools.Commands.Echo;
