with Ada.Strings.Unbounded;

package body Posix_Tools.Text.Stat_Formats is
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   function Render_Format
     (Format               : String;
      Path                 : String;
      Mode_Image           : String;
      Kind_Name            : String;
      Group_Id_Image       : String;
      Size_Image           : String;
      Creation_Time_Image  : String;
      Creation_Epoch_Image : String;
      Access_Time_Image    : String;
      Access_Epoch_Image   : String;
      Modify_Time_Image    : String;
      Modify_Epoch_Image   : String;
      User_Id_Image        : String) return String
   is
      Output : Unbounded_String;
      I      : Positive := Format'First;

      function Field_Value (Code : Character) return String is
      begin
         case Code is
            when '%' =>
               return "%";
            when 'a' =>
               return Mode_Image;
            when 'F' =>
               return Kind_Name;
            when 'g' =>
               return Group_Id_Image;
            when 'n' =>
               return Path;
            when 's' =>
               return Size_Image;
            when 'w' =>
               return Creation_Time_Image;
            when 'W' =>
               return Creation_Epoch_Image;
            when 'x' =>
               return Access_Time_Image;
            when 'X' =>
               return Access_Epoch_Image;
            when 'y' =>
               return Modify_Time_Image;
            when 'Y' =>
               return Modify_Epoch_Image;
            when 'u' =>
               return User_Id_Image;
            when others =>
               return "%" & Code;
         end case;
      end Field_Value;
   begin
      while I <= Format'Last loop
         if Format (I) = '%' and then I < Format'Last then
            Append (Output, Field_Value (Format (I + 1)));
            I := I + 2;
         elsif Format (I) = '\' and then I < Format'Last then
            case Format (I + 1) is
               when 'n' =>
                  Append (Output, LF);
               when 't' =>
                  Append (Output, Character'Val (9));
               when '\' =>
                  Append (Output, '\');
               when others =>
                  Append (Output, Format (I + 1));
            end case;
            I := I + 2;
         else
            Append (Output, Format (I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Output);
   end Render_Format;
end Posix_Tools.Text.Stat_Formats;
