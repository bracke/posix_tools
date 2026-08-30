with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.Printf_Execution is
   procedure Execute
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Format         : String;
      First_Argument : Positive;
      Ok             : out Boolean);
end Posix_Tools.Commands.Printf_Execution;
