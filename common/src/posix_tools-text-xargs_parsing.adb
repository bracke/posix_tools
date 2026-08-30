with Ada.Strings.Unbounded;
with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Xargs_Parsing is
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   function Parse_Blank_Delimited
     (Data           : String;
      Has_Eof_Marker : Boolean;
      Eof_Marker     : String) return Parse_Result
   is
      Result : Parse_Result;
      I      : Positive := Data'First;
      Stop   : Boolean := False;
   begin
      if Data = "" then
         return Result;
      end if;

      while I <= Data'Last and then not Stop loop
         while I <= Data'Last
           and then Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Data (I))
         loop
            I := I + 1;
         end loop;
         exit when I > Data'Last;

         declare
            Item : Unbounded_String;
         begin
            while I <= Data'Last
              and then not Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Data (I))
            loop
               if Data (I) = Character'Val (39) then
                  I := I + 1;
                  while I <= Data'Last and then Data (I) /= Character'Val (39) loop
                     Append (Item, Data (I));
                     I := I + 1;
                  end loop;
                  if I > Data'Last then
                     Result.Status := Unmatched_Single_Quote;
                     return Result;
                  end if;
                  I := I + 1;
               elsif Data (I) = Character'Val (34) then
                  I := I + 1;
                  while I <= Data'Last and then Data (I) /= Character'Val (34) loop
                     if Data (I) = '\' and then I < Data'Last then
                        I := I + 1;
                     end if;
                     Append (Item, Data (I));
                     I := I + 1;
                  end loop;
                  if I > Data'Last then
                     Result.Status := Unmatched_Double_Quote;
                     return Result;
                  end if;
                  I := I + 1;
               elsif Data (I) = '\' then
                  if I = Data'Last then
                     Result.Status := Unfinished_Escape;
                     return Result;
                  end if;
                  I := I + 1;
                  Append (Item, Data (I));
                  I := I + 1;
               else
                  Append (Item, Data (I));
                  I := I + 1;
               end if;
            end loop;

            if Has_Eof_Marker and then To_String (Item) = Eof_Marker then
               Stop := True;
            else
               Result.Items.Append (To_String (Item));
            end if;
         end;
      end loop;

      return Result;
   end Parse_Blank_Delimited;

   function Parse_Line_Delimited
     (Data           : String;
      Has_Eof_Marker : Boolean;
      Eof_Marker     : String) return Parse_Result
   is
      Result : Parse_Result;
      I      : Positive := Data'First;
   begin
      if Data = "" then
         return Result;
      end if;

      while I <= Data'Last loop
         declare
            Start : constant Positive := I;
         begin
            while I <= Data'Last and then Data (I) /= LF loop
               I := I + 1;
            end loop;

            if I > Start then
               declare
                  Item : constant String := Data (Start .. I - 1);
               begin
                  exit when Has_Eof_Marker and then Item = Eof_Marker;
                  Result.Items.Append (Item);
               end;
            end if;

            I := I + 1;
         end;
      end loop;

      return Result;
   end Parse_Line_Delimited;

   function Parse_Null_Delimited
     (Data           : String;
      Has_Eof_Marker : Boolean;
      Eof_Marker     : String) return Parse_Result
   is
      Result : Parse_Result;
      I      : Positive := Data'First;
   begin
      if Data = "" then
         return Result;
      end if;

      while I <= Data'Last loop
         declare
            Start : constant Positive := I;
         begin
            while I <= Data'Last and then Data (I) /= Character'Val (0) loop
               I := I + 1;
            end loop;
            declare
               Item : constant String := Data (Start .. I - 1);
            begin
               exit when Has_Eof_Marker and then Item = Eof_Marker;
               Result.Items.Append (Item);
            end;
            I := I + 1;
         end;
      end loop;

      return Result;
   end Parse_Null_Delimited;

   function Parse_Input
     (Data             : String;
      Null_Delimited   : Boolean;
      Replacement_Mode : Boolean;
      Has_Eof_Marker   : Boolean;
      Eof_Marker       : String) return Parse_Result
   is
   begin
      if Null_Delimited then
         return Parse_Null_Delimited (Data, Has_Eof_Marker, Eof_Marker);
      elsif Replacement_Mode then
         return Parse_Line_Delimited (Data, Has_Eof_Marker, Eof_Marker);
      else
         return Parse_Blank_Delimited (Data, Has_Eof_Marker, Eof_Marker);
      end if;
   end Parse_Input;
end Posix_Tools.Text.Xargs_Parsing;
