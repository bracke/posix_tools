with Ada.Strings.Unbounded;

--  Reading a file into memory with a bound on how much of it is taken, so a
--  file larger than expected costs no more than the bound.
package Explore.Files is
   --  At most Limit bytes from the start of the file at Path. Ok is False
   --  when it cannot be read.
   procedure Read_Head
     (Path  : String;
      Limit : Positive;
      Data  : out Ada.Strings.Unbounded.Unbounded_String;
      Ok    : out Boolean);
end Explore.Files;
