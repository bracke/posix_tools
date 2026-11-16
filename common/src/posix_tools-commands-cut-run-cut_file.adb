separate (Posix_Tools.Commands.Cut.Run)
procedure Cut_File (Name : String; Ok : out Boolean) is
   function Selects_All return Boolean is
     (Ranges.Length = 1
      and then Ranges.First_Element.First = 1
      and then Ranges.First_Element.Last = 0);

   procedure Copy_All_Chunks (Ok : out Boolean);
   --  Byte-oriented selections need no record-sized allocation.  This
   --  also covers -c in single-byte locales.
   procedure Cut_Chunks (Ok : out Boolean);
   procedure Cut_Character_Chunks (Ok : out Boolean);

   procedure Copy_All_Chunks (Ok : out Boolean) is separate;

   procedure Cut_Chunks (Ok : out Boolean) is separate;

   procedure Cut_Character_Chunks (Ok : out Boolean) is separate;

   procedure Each_Line
     (Ignored    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : String;
      Terminated : Boolean);

   procedure Each_Line
     (Ignored    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : String;
      Terminated : Boolean)
   is
      pragma Unreferenced (Ignored, Terminated);
   begin
      Emit_Line (Line);
   end Each_Line;

   procedure Iterate is new
     Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Line
       (Action        => Each_Line,
        Buffer_Length =>
          Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
begin
   if Mode in 'b' | 'c' and then Selects_All then
      Copy_All_Chunks (Ok);
   elsif (Mode = 'b' and then not (No_Split and then Characters))
     or else (Mode = 'c' and then not Characters)
   then
      Cut_Chunks (Ok);
   elsif Mode = 'c' or else (Mode = 'b' and then No_Split) then
      Cut_Character_Chunks (Ok);
   else
      Iterate (Context, Name, Ok);
   end if;
end Cut_File;
