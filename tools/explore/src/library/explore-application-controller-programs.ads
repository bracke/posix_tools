with Posix_Tools.Arguments;

--  Running other programs on the entries: their openers, a shell command, or
--  a shell; or, when explore chooses files for another program, writing the
--  entries down for it.
private package Explore.Application.Controller.Programs is
   --  Open the entries the next command is for with their opener, or, when
   --  explore chooses files for another program, write them down and quit.
   procedure Open_Targets (State : in out Session);

   --  Run the shell with Arguments. Detached, it is left to run on its own;
   --  otherwise the terminal is handed to it until it ends -- with Pause,
   --  until Enter is pressed after that -- and then taken back and redrawn.
   procedure Run_Program
     (State     : in out Session;
      Arguments : Posix_Tools.Arguments.Vector;
      Detach    : Boolean;
      Pause     : Boolean);
end Explore.Application.Controller.Programs;
