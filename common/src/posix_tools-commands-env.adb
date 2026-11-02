with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Env is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Pairs       : Posix_Tools.Arguments.Vector;
      First       : Positive;
      Valid       : Boolean;

      function Equal_Position (Text : String) return Natural;

      procedure Remove_Name (Name : String);

      procedure Replace_Or_Append (Pair : String);

      function Equal_Position (Text : String) return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = '=' then
               return I;
            end if;
         end loop;
         return 0;
      end Equal_Position;

      procedure Remove_Name (Name : String) is
         I : Natural := 1;
      begin
         while I <= Natural (Pairs.Length) loop
            declare
               Existing       : constant String := Pairs.Element (I);
               Existing_Equal : constant Natural := Equal_Position (Existing);
            begin
               if Existing_Equal > 0
                 and then Existing (Existing'First .. Existing_Equal - 1) = Name
               then
                  Pairs.Delete (I);
               else
                  I := I + 1;
               end if;
            end;
         end loop;
      end Remove_Name;

      procedure Replace_Or_Append (Pair : String) is
         Equal : constant Natural := Equal_Position (Pair);
      begin
         if Equal = 0 then
            return;
         end if;

         for I in 1 .. Natural (Pairs.Length) loop
            declare
               Existing       : constant String := Pairs.Element (I);
               Existing_Equal : constant Natural := Equal_Position (Existing);
            begin
               if Existing_Equal > 0
                 and then Existing (Existing'First .. Existing_Equal - 1) = Pair (Pair'First .. Equal - 1)
               then
                  Pairs.Replace_Element (I, Pair);
                  return;
               end if;
            end;
         end loop;

         Pairs.Append (Pair);
      end Replace_Or_Append;

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
      begin
         Valid := True;
         if Name = 'i' then
            Pairs.Clear;
         elsif Value = "" or else (for some Ch of Value => Ch = '=') then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
            Valid := False;
         else
            Remove_Name (Value);
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Pairs := Context.Environment_Pairs;
      Parse (Context, Result, "iu", "u", First, Valid);
      if not Valid then
         return;
      end if;
      while First <= Context.Argument_Count
        and then (for some Ch of Context.Argument (First) => Ch = '=')
      loop
         if Context.Argument (First) (Context.Argument (First)'First) = '=' then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Context.Argument (First));
            return;
         end if;
         Replace_Or_Append (Context.Argument (First));
         First := First + 1;
      end loop;

      if First <= Context.Argument_Count then
         declare
            Utility   : constant String := Context.Argument (First);
            Arguments : Posix_Tools.Arguments.Vector;
            Exit_Code : Integer := 0;
         begin
            for I in First + 1 .. Context.Argument_Count loop
               Arguments.Append (Context.Argument (I));
            end loop;

            if not Context.Execute_Utility_With_Environment (Utility, Arguments, Pairs, Exit_Code) then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Utility, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               if Exit_Code in Integer (Posix_Tools.Exit_Status.Utility_Cannot_Invoke)
                 .. Integer (Posix_Tools.Exit_Status.Utility_Not_Found)
               then
                  Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
               else
                  Result.Status := Posix_Tools.Exit_Status.Utility_Not_Found;
               end if;
            elsif Exit_Code = 0 then
               Posix_Tools.Commands.Helpers.Finish (Context, Result);
            elsif Exit_Code in Integer (Posix_Tools.Exit_Status.Code'First)
              .. Integer (Posix_Tools.Exit_Status.Code'Last)
            then
               Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
            else
               Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
            end if;
            return;
         end;
      end if;

      for I in 1 .. Natural (Pairs.Length) loop
         Context.Put_Line (Pairs.Element (I));
      end loop;

      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;
end Posix_Tools.Commands.Env;
