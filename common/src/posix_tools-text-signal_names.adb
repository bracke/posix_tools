with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Signal_Names
  with SPARK_Mode => On
is
   function Lowercase (Value : Character) return Character;

   function Matches (Text, Name : String) return Boolean;

   function Is_SIG_Prefixed (Text : String) return Boolean is
   begin
      if Text'Length <= 3 then
         return False;
      else
         pragma Assert (Text'First <= Text'Last - 3);
         return Matches (Text (Text'First .. Text'First + 2), "sig");
      end if;
   end Is_SIG_Prefixed;

   function Known_Signal_Name (Text : String) return Signal_Name is
      First : Integer := Text'First;
   begin
      if Text = "" then
         return Unknown_Signal_Name;
      end if;

      if Text'Length > 3 and then Is_SIG_Prefixed (Text) then
         pragma Assert (Text'First <= Text'Last - 3);
         First := Text'First + 3;
      end if;

      if Matches (Text (First .. Text'Last), "hup") then
         return Hangup_Name;
      elsif Matches (Text (First .. Text'Last), "int") then
         return Interrupt_Name;
      elsif Matches (Text (First .. Text'Last), "quit") then
         return Quit_Name;
      elsif Matches (Text (First .. Text'Last), "kill") then
         return Kill_Name;
      elsif Matches (Text (First .. Text'Last), "term") then
         return Terminate_Name;
      elsif Matches (Text (First .. Text'Last), "stop") then
         return Stop_Name;
      elsif Matches (Text (First .. Text'Last), "tstp") then
         return Terminal_Stop_Name;
      elsif Matches (Text (First .. Text'Last), "cont") then
         return Continue_Name;
      elsif Matches (Text (First .. Text'Last), "pipe") then
         return Pipe_Name;
      else
         return Unknown_Signal_Name;
      end if;
   end Known_Signal_Name;

   function Lowercase (Value : Character) return Character is
   begin
      if Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper (Value) then
         return Posix_Tools.Text.Byte_Classes.To_ASCII_Lower (Value);
      else
         return Value;
      end if;
   end Lowercase;

   function Matches (Text, Name : String) return Boolean is
      Text_Index : Integer := Text'First;
   begin
      if Text'Length /= Name'Length then
         return False;
      end if;

      for Name_Index in Name'Range loop
         pragma Loop_Invariant (Text_Index in Text'Range);
         pragma Loop_Invariant (Text_Index - Text'First = Name_Index - Name'First);

         if Lowercase (Text (Text_Index)) /= Lowercase (Name (Name_Index)) then
            return False;
         end if;

         if Name_Index < Name'Last then
            Text_Index := Text_Index + 1;
         end if;
      end loop;

      return True;
   end Matches;
end Posix_Tools.Text.Signal_Names;
