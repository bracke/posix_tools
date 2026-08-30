package body Posix_Tools.Text.File_Magic_Fields
  with SPARK_Mode => On
is
   function Next_Field (Line : String; From : Positive) return Magic_Field is
      Escaped : Boolean := False;
   begin
      for I in From .. Line'Last loop
         if Escaped then
            Escaped := False;
         elsif Line (I) = '\' then
            Escaped := True;
         elsif Line (I) = ':' then
            if I = Line'Last then
               return (Last => I - 1, Next => From, At_End => True);
            else
               return (Last => I - 1, Next => I + 1, At_End => False);
            end if;
         end if;
      end loop;

      return (Last => Line'Last, Next => From, At_End => True);
   end Next_Field;
end Posix_Tools.Text.File_Magic_Fields;
