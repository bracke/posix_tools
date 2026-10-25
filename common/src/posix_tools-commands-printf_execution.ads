with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.Printf_Execution is
   --  Write Format with the arguments from First_Argument on, reusing the
   --  format while it consumes arguments (XCU printf). Format_Ok is False
   --  when the format itself cannot be used; Arguments_Ok is False when an
   --  argument of a numeric conversion was not completely a number, which
   --  was diagnosed and written as the value converted so far.
   procedure Execute
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Format         : String;
      First_Argument : Positive;
      Format_Ok      : out Boolean;
      Arguments_Ok   : out Boolean);
end Posix_Tools.Commands.Printf_Execution;
