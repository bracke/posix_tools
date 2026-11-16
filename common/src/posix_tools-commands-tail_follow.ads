with Posix_Tools.Commands.Contexts;
with Posix_Tools.Host_Adapters.File_System;

package Posix_Tools.Commands.Tail_Follow is
   type Follow_Mode is (No_Follow, Follow_Descriptor, Follow_Name);
   type Follow_File_Array is array (Positive range <>) of aliased
     Posix_Tools.Host_Adapters.File_System.Follow_File;
   type Follow_Eligibility_Array is array (Positive range <>) of Boolean;

   procedure Follow_File_Operands
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      First_File  : Positive;
      Last_File   : Natural;
      Sources     : Natural;
      Follow      : Follow_Mode;
      Files       : in out Follow_File_Array;
      Eligible    : in out Follow_Eligibility_Array;
      All_Ok      : in out Boolean)
     with
       Pre =>
         Follow /= No_Follow
         and then Files'First = Eligible'First
         and then Files'Last = Eligible'Last;

   procedure Follow_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      All_Ok  : in out Boolean);
end Posix_Tools.Commands.Tail_Follow;
