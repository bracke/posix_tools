package body Posix_Tools.Text.Logical_Paths
  with SPARK_Mode => On
is
   function Dot_Component
     (Length      : Natural;
      First_Char  : Character;
      Second_Char : Character) return Boolean
   is
     ((Length = 1 and then First_Char = '.')
      or else (Length = 2 and then First_Char = '.' and then Second_Char = '.'));

   function Usable_Logical_Path (Path : String) return Boolean is
      Component_Length : Natural := 0;
      First_Char       : Character := Character'Val (0);
      Second_Char      : Character := Character'Val (0);
   begin
      if Path = "" or else Path (Path'First) /= '/' then
         return False;
      end if;

      for I in Path'Range loop
         pragma Loop_Invariant (Component_Length <= 3);

         if I > Path'First then
            if Path (I) = '/' then
               if Dot_Component (Component_Length, First_Char, Second_Char) then
                  return False;
               end if;

               Component_Length := 0;
               First_Char := Character'Val (0);
               Second_Char := Character'Val (0);
            else
               if Component_Length = 0 then
                  First_Char := Path (I);
               elsif Component_Length = 1 then
                  Second_Char := Path (I);
               end if;

               if Component_Length < 3 then
                  Component_Length := Component_Length + 1;
               end if;
            end if;
         end if;
      end loop;

      return not Dot_Component (Component_Length, First_Char, Second_Char);
   end Usable_Logical_Path;
end Posix_Tools.Text.Logical_Paths;
