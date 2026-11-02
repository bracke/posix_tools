with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Numbers;

package body Posix_Tools.Commands.Head is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Posix_Tools.Numbers.Parse_Status;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Prefix_Mode is (Line_Mode, Byte_Mode);

      First_File : Positive;
      Valid      : Boolean;
      Count      : constant Natural := Context.Argument_Count;
      Ok         : Boolean;
      All_Ok     : Boolean := True;
      Sources    : Natural;
      Requested  : Posix_Tools.Numbers.Count := 10;
      Mode       : Prefix_Mode := Line_Mode;

      --  -n or -c, with its count Value.
      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         Parsed : constant Posix_Tools.Numbers.Parse_Result := Posix_Tools.Numbers.Parse_Nonnegative (Value);
      begin
         if Parsed.Status /= Posix_Tools.Numbers.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, (if Name = 'n' then Invalid_Line_Count else Invalid_Byte_Count), Value);
            Valid := False;
         else
            Requested := Parsed.Value;
            Mode := (if Name = 'n' then Line_Mode else Byte_Mode);
            Valid := True;
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);

      procedure Copy_Prefix (File_Name : String; Ok : out Boolean) is
      begin
         if Mode = Line_Mode then
            Posix_Tools.Commands.File_Helpers.Copy_Line_Prefix (Context, File_Name, Requested, Ok);
         else
            Posix_Tools.Commands.File_Helpers.Copy_Byte_Prefix (Context, File_Name, Requested, Ok);
         end if;
      end Copy_Prefix;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "cn", "cn", First_File, Valid);
      if not Valid then
         return;
      end if;

      Sources := (if First_File > Count then 1 else Count - First_File + 1);
      if First_File > Count then
         Copy_Prefix ("-", Ok);
         All_Ok := Ok;
      else
         for I in First_File .. Count loop
            if Sources > 1 then
               if I > First_File then
                  Context.Put_Line ("");
                  if Context.Output_Failed then
                     All_Ok := False;
                     exit;
                  end if;
               end if;
               Context.Put_Line ("==> " & Context.Argument (I) & " <==");
               if Context.Output_Failed then
                  All_Ok := False;
                  exit;
               end if;
            end if;

            Copy_Prefix (Context.Argument (I), Ok);
            All_Ok := All_Ok and Ok;
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Head;
