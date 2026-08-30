package body Posix_Tools.Extension_Options
  with SPARK_Mode => On
is
   function Intercept_Action
     (Argument_Count : Natural;
      First_Argument : String;
      Conventional   : Boolean := True) return Extension_Action
   is
   begin
      if Argument_Count = 0 then
         return No_Extension;
      end if;

      if Conventional or else Argument_Count = 1 then
         if First_Argument = "--help" then
            return Render_Help;
         elsif First_Argument = "--version" then
            return Render_Version;
         elsif First_Argument = "--posix-tools-identify" and then Argument_Count = 1 then
            return Render_Identity;
         end if;
      end if;

      return No_Extension;
   end Intercept_Action;
end Posix_Tools.Extension_Options;
