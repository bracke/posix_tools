with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Nl_Numbering is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.NL_Fields.Logical_Section;

   LF : constant Character := Character'Val (10);

   function Active_Mode (State : Numbering_State) return Posix_Tools.Text.NL_Fields.Number_Mode;

   procedure Emit_Prefix
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      State    : Numbering_State;
      Numbered : Boolean);

   function Is_Logical_Delimiter
     (State       : Numbering_State;
      Line        : String;
      New_Section : out Posix_Tools.Text.NL_Fields.Logical_Section) return Boolean;

   procedure Process_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      State   : in out Numbering_State;
      Line    : String);

   function Active_Mode (State : Numbering_State) return Posix_Tools.Text.NL_Fields.Number_Mode is
   begin
      case State.Section is
         when Posix_Tools.Text.NL_Fields.Header_Section => return State.Header_Mode;
         when Posix_Tools.Text.NL_Fields.Body_Section => return State.Body_Mode;
         when Posix_Tools.Text.NL_Fields.Footer_Section => return State.Footer_Mode;
         when Posix_Tools.Text.NL_Fields.No_Section => return State.Body_Mode;
      end case;
   end Active_Mode;

   procedure Emit_Prefix
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      State    : Numbering_State;
      Numbered : Boolean)
   is
      Text : constant String :=
        (if Numbered
         then Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (State.Value)
         else "");
   begin
      if Text'Length < State.Width then
         for I in 1 .. State.Width - Text'Length loop
            Context.Put (" ");
            exit when Context.Output_Failed;
         end loop;
      end if;

      if not Context.Output_Failed and then Numbered then
         Context.Put (Text);
      end if;

      if not Context.Output_Failed then
         Context.Put (To_String (State.Separator));
      end if;
   end Emit_Prefix;

   function Is_Logical_Delimiter
     (State       : Numbering_State;
      Line        : String;
      New_Section : out Posix_Tools.Text.NL_Fields.Logical_Section) return Boolean
   is
   begin
      New_Section :=
        Posix_Tools.Text.NL_Fields.Logical_Section_For
          (Line, State.Delimiter (1), State.Delimiter (2));
      if New_Section = Posix_Tools.Text.NL_Fields.No_Section then
         New_Section := State.Section;
         return False;
      else
         return True;
      end if;
   end Is_Logical_Delimiter;

   procedure Number_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      State   : in out Numbering_State;
      Name    : String;
      Ok      : out Boolean)
   is
      Data : Unbounded_String;
   begin
      Posix_Tools.Commands.File_Helpers.Read_All (Context, Name, Data, Ok);
      if Ok then
         declare
            Current : Unbounded_String;
         begin
            Ok := True;
            for Ch of To_String (Data) loop
               Append (Current, Ch);
               if Ch = LF then
                  Process_Line (Context, State, To_String (Current));
                  Current := Null_Unbounded_String;
                  if Context.Output_Failed then
                     Ok := False;
                     return;
                  end if;
               end if;
            end loop;

            if Length (Current) > 0 then
               Process_Line (Context, State, To_String (Current));
            end if;

            Ok := not Context.Output_Failed;
         end;
      end if;
   end Number_File;

   procedure Process_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      State   : in out Numbering_State;
      Line    : String)
   is
      use type Posix_Tools.Text.NL_Fields.Number_Mode;

      New_Section : Posix_Tools.Text.NL_Fields.Logical_Section;
   begin
      if Is_Logical_Delimiter (State, Line, New_Section) then
         State.Section := New_Section;
         if New_Section = Posix_Tools.Text.NL_Fields.Header_Section
           and then not State.No_Restart
         then
            State.Value := State.Initial_Value;
         end if;
      else
         declare
            Mode     : constant Posix_Tools.Text.NL_Fields.Number_Mode := Active_Mode (State);
            Numbered : constant Boolean :=
              Mode = Posix_Tools.Text.NL_Fields.All_Lines
              or else
                (Mode = Posix_Tools.Text.NL_Fields.Nonempty_Lines
                 and then not Posix_Tools.Text.NL_Fields.Is_Empty_Line (Line));
         begin
            Emit_Prefix (Context, State, Numbered);
            if not Context.Output_Failed then
               Context.Put (Line);
            end if;
            if Numbered then
               State.Value := State.Value + State.Increment;
            end if;
         end;
      end if;
   end Process_Line;
end Posix_Tools.Commands.Nl_Numbering;
