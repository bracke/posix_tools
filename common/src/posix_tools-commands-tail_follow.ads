with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.Tail_Follow is
   type Follow_Mode is (No_Follow, Follow_Descriptor, Follow_Name);

   procedure Follow_File_Operands
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      First_File  : Positive;
      Last_File   : Natural;
      Sources     : Natural;
      Follow      : Follow_Mode;
      All_Ok      : in out Boolean)
     with Pre => Follow /= No_Follow;

   procedure Follow_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      All_Ok  : in out Boolean);
end Posix_Tools.Commands.Tail_Follow;
