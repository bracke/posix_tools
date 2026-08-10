package Posix_Tools.Exit_Status is
   pragma Pure;

   type Code is new Integer range 0 .. 255;

   Success             : constant Code := 0;
   Operational_Failure : constant Code := 1;
   Invalid_Usage       : constant Code := 2;
   Internal_Failure    : constant Code := 125;
end Posix_Tools.Exit_Status;
