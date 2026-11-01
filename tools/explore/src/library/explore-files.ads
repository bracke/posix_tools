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

   --  Where Path leads, as a path to go to is followed: to the directory it
   --  names, Name empty, or to the directory of the file it names, Name the
   --  file's; both with links resolved. Found is False when it names nothing.
   procedure Locate
     (Path      : String;
      Directory : out Ada.Strings.Unbounded.Unbounded_String;
      Name      : out Ada.Strings.Unbounded.Unbounded_String;
      Found     : out Boolean);
end Explore.Files;
