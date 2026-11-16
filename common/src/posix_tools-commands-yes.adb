with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Yes is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Line : Unbounded_String :=
        (if Context.Argument_Count = 0 then To_Unbounded_String ("y") else Null_Unbounded_String);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if I > 1 then
            Append (Line, " ");
         end if;
         Append (Line, Context.Argument (I));
      end loop;

      declare
         One_Line : constant String := To_String (Line) & Character'Val (10);
         Target_Block_Size : constant := 64 * 1024;
         Repetitions : constant Positive :=
           (if One_Line'Length >= Target_Block_Size
            then 1
            else Target_Block_Size / One_Line'Length);
         Block : String (1 .. One_Line'Length * Repetitions);
      begin
         for I in 0 .. Repetitions - 1 loop
            Block
              (Block'First + I * One_Line'Length
               .. Block'First + (I + 1) * One_Line'Length - 1) := One_Line;
         end loop;

         while not Context.Output_Failed loop
            Context.Put (Block);
         end loop;
      end;

      Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
   end Run;
end Posix_Tools.Commands.Yes;
