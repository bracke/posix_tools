with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;

package body Posix_Tools.Commands.Cat is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Ok      : Boolean;
      All_Ok  : Boolean := True;
      Count   : constant Natural := Context.Argument_Count;
      First   : Positive;
      Valid   : Boolean;

      --  -u, which asks for unbuffered output, is the one option; it needs
      --  no handling, as cat writes each chunk it reads.
      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Name, Value, Result);
      begin
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "u", "", First, Valid);
      if not Valid then
         return;
      end if;

      if Count < First then
         Posix_Tools.Commands.File_Helpers.Copy_File (Context, "-", Ok);
         All_Ok := Ok;
      else
         for I in First .. Count loop
            Posix_Tools.Commands.File_Helpers.Copy_File (Context, Context.Argument (I), Ok);
            All_Ok := All_Ok and Ok;
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Cat;
