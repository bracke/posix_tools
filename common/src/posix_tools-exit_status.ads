package Posix_Tools.Exit_Status
  with SPARK_Mode => On
is
   pragma Pure;

   type Code is new Integer range 0 .. 255;

   Success               : constant Code := 0;
   Operational_Failure   : constant Code := 1;
   Invalid_Usage         : constant Code := 2;
   Internal_Failure      : constant Code := 125;
   Utility_Cannot_Invoke : constant Code := 126;
   Utility_Not_Found     : constant Code := 127;

   Xargs_Utility_Failed         : constant Code := 123;
   Xargs_Utility_Requested_Stop : constant Code := 124;

   function Classify_Xargs_Status
     (Utility_Ran    : Boolean;
      Utility_Status : Integer) return Code is
     (if not Utility_Ran then
        Utility_Not_Found
      elsif Utility_Status = 126 then
        Utility_Cannot_Invoke
      elsif Utility_Status = 127 then
        Utility_Not_Found
      elsif Utility_Status = 255 then
        Xargs_Utility_Requested_Stop
      elsif Utility_Status in 1 .. 125 then
        Xargs_Utility_Failed
      else
        Operational_Failure)
     with
       Post =>
         (if not Utility_Ran then
            Classify_Xargs_Status'Result = Utility_Not_Found)
         and then
           (if Utility_Ran and then Utility_Status = 126 then
              Classify_Xargs_Status'Result = Utility_Cannot_Invoke)
         and then
           (if Utility_Ran and then Utility_Status = 127 then
              Classify_Xargs_Status'Result = Utility_Not_Found)
         and then
           (if Utility_Ran and then Utility_Status = 255 then
              Classify_Xargs_Status'Result = Xargs_Utility_Requested_Stop)
         and then
           (if Utility_Ran and then Utility_Status in 1 .. 125 then
              Classify_Xargs_Status'Result = Xargs_Utility_Failed)
         and then
           (if Utility_Ran
             and then Utility_Status not in 1 .. 127
             and then Utility_Status /= 255
            then
              Classify_Xargs_Status'Result = Operational_Failure);
end Posix_Tools.Exit_Status;
