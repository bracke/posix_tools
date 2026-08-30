package Posix_Tools.Extension_Options
  with SPARK_Mode => On
is
   type Extension_Action is
     (No_Extension,
      Render_Help,
      Render_Version,
      Render_Identity);

   function Intercept_Action
     (Argument_Count : Natural;
      First_Argument : String;
      Conventional   : Boolean := True) return Extension_Action
   with Post =>
     (if Argument_Count = 0 then
        Intercept_Action'Result = No_Extension)
     and then
       (if not Conventional and then Argument_Count /= 1 then
          Intercept_Action'Result = No_Extension)
     and then
       (if Intercept_Action'Result = Render_Identity then
          Argument_Count = 1 and then First_Argument = "--posix-tools-identify");
end Posix_Tools.Extension_Options;
