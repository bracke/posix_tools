with Posix_Tools.Commands.Contexts;
with Posix_Tools.Numbers;
with Posix_Tools.Tail_Counts;

package Posix_Tools.Commands.Tail_Bytes is
   procedure Copy
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Requested : Posix_Tools.Numbers.Count;
      Origin    : Posix_Tools.Tail_Counts.Count_Origin;
      Ok        : out Boolean);
end Posix_Tools.Commands.Tail_Bytes;
