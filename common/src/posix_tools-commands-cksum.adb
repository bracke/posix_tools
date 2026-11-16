with Ada.Streams;

with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Numbers;
with Posix_Tools.Text.Checksums;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Cksum is
   use type Ada.Streams.Stream_Element_Offset;
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      All_Ok : Boolean := True;
      First  : Positive := 1;

      procedure Emit (Name : String);

      procedure Emit (Name : String) is
         State : Posix_Tools.Text.Checksums.POSIX_Cksum_State :=
           Posix_Tools.Text.Checksums.Initial_POSIX_Cksum_State;
         Ok    : Boolean;

         procedure Hash
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         procedure Hash
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Ignored);
         begin
            if Last >= Buffer'First then
               Posix_Tools.Text.Checksums.Update
                 (State, Buffer, Last);
            end if;
         end Hash;

         procedure Iterate is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
             (Action        => Hash,
              Buffer_Length =>
                Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
      begin
         Iterate (Context, Name, Ok);
         if Ok then
            Context.Put_Line
              (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                 (Long_Long_Integer
                    (Posix_Tools.Text.Checksums.Digest (State))) & " "
               & Posix_Tools.Numbers.Count_Image
                   (Posix_Tools.Text.Checksums.Length (State))
               & (if Name = "-" then "" else " " & Name));
         else
            All_Ok := False;
         end if;
      end Emit;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count >= 1 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Emit ("-");
      else
         for I in First .. Context.Argument_Count loop
            Emit (Context.Argument (I));
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Cksum;
