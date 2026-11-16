separate (Posix_Tools.Commands.Cut)
procedure Run
  (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
   Result  : out Posix_Tools.Commands.Results.Result)
is
   Mode       : Character := Character'Val (0);
   Ranges     : Range_Vectors.Vector;
   Delimiter  : Unbounded_String := To_Unbounded_String (Character'Val (9) & "");
   Has_Delimiter : Boolean := False;
   Suppress   : Boolean := False;
   No_Split   : Boolean := False;
   First_File : Positive;
   Valid      : Boolean;
   All_Ok     : Boolean := True;
   Pending_Output : Unbounded_String;
   Characters : constant Boolean :=
     Posix_Tools.Commands.Text_Helpers.Collation.Is_Multibyte_Locale
       (Context.Category_Locale (Posix_Tools.Commands.Contexts.Character_Classification));

   procedure Cut_File (Name : String; Ok : out Boolean);
   procedure Emit_Line (Line : String);
   procedure Flush_Output;
   procedure Handle
     (Name   : Character;
      Value  : String;
      Result : in out Posix_Tools.Commands.Results.Result;
      Valid  : out Boolean);

   procedure Flush_Output is
   begin
      if Length (Pending_Output) > 0
        and then not Context.Output_Failed
      then
         Context.Put (To_String (Pending_Output));
      end if;
      Pending_Output := Null_Unbounded_String;
   end Flush_Output;

   procedure Cut_File (Name : String; Ok : out Boolean) is separate;

   procedure Emit_Line (Line : String) is separate;

   procedure Handle
     (Name   : Character;
      Value  : String;
      Result : in out Posix_Tools.Commands.Results.Result;
      Valid  : out Boolean)
   is
   begin
      Valid := False;
      case Name is
         when 's' =>
            Suppress := True;
         when 'n' =>
            No_Split := True;
         when 'd' =>
            --  One character: in a UTF-8 locale it may take several bytes.
            if Value'Length = 0
              or else (if Characters then Character_Width (Value, Value'First) /= Value'Length
                       else Value'Length /= 1)
            then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
               return;
            end if;
            Delimiter := To_Unbounded_String (Value);
            Has_Delimiter := True;
         when others =>
            --  -b, -c or -f, with its list.
            if Mode /= Character'Val (0) then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Multiple_List_Options);
               return;
            elsif Value = "" then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, "-" & Name);
               return;
            elsif not Parse_List (Value, Ranges) then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
               return;
            end if;
            Mode := Name;
      end case;
      Valid := True;
   end Handle;

   procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
begin
   if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
      return;
   end if;

   Parse (Context, Result, "bcdfns", "bcdf", First_File, Valid);
   if not Valid then
      return;
   end if;

   if Mode = Character'Val (0) then
      Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
      return;
   end if;
   if No_Split and then Mode /= 'b' then
      Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, "-n");
      return;
   end if;
   if (Has_Delimiter or else Suppress) and then Mode /= 'f' then
      Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Field_Option);
      return;
   end if;
   if Context.Argument_Count < First_File then
      Cut_File ("-", All_Ok);
   else
      for I in First_File .. Context.Argument_Count loop
         declare
            Ok : Boolean;
         begin
            Cut_File (Context.Argument (I), Ok);
            All_Ok := All_Ok and Ok;
         end;
      end loop;
   end if;
   Flush_Output;
   All_Ok := All_Ok and then not Context.Output_Failed;
   Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
end Run;
