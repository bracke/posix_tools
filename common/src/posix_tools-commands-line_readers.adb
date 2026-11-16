with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.Line_Readers is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element;
   use type Posix_Tools.Host_Adapters.Input_Files.Read_Outcome;
   package Inputs renames Posix_Tools.Host_Adapters.Input_Files;

   procedure Close (Self : in out Reader; Ok : out Boolean) is
   begin
      if Inputs.Is_Open (Self.File) then
         Inputs.Close (Self.File, Ok);
      else
         Ok := True;
      end if;
      Self.At_End := True;
   end Close;

   procedure Open (Self : in out Reader; Name : String; Ok : out Boolean) is
      Closed : Boolean;
   begin
      Close (Self, Closed);
      if not Closed then
         Ok := False;
         return;
      end if;

      Self.Is_Stdin := Name = "-";
      Self.Next := Self.Buffer'First;
      Self.Last := Self.Buffer'First - 1;
      Self.At_End := False;
      if Self.Is_Stdin then
         Ok := True;
      else
         Inputs.Open (Self.File, Name, Ok);
      end if;
   end Open;

   procedure Next
     (Self      : in out Reader;
      Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line      : out Unbounded_String;
      Available : out Boolean;
      Ok        : out Boolean)
   is
      Outcome : Inputs.Read_Outcome;
      Start   : Ada.Streams.Stream_Element_Offset;
      Has_Data : Boolean := False;
   begin
      Available := False;
      Ok := True;

      loop
         if Self.Next <= Self.Last then
            Start := Self.Next;
            while Self.Next <= Self.Last
              and then Self.Buffer (Self.Next) /= Ada.Streams.Stream_Element (10)
            loop
               Self.Next := Self.Next + 1;
            end loop;
            if Start < Self.Next then
               declare
                  Text : constant String :=
                    Posix_Tools.Streams.Bytes.To_String
                      (Self.Buffer (Start .. Self.Next - 1), Self.Next - 1);
               begin
                  if Has_Data then
                     Append (Line, Text);
                  else
                     Set_Unbounded_String (Line, Text);
                     Has_Data := True;
                  end if;
               end;
            end if;
            if Self.Next <= Self.Last then
               if not Has_Data then
                  Set_Unbounded_String (Line, "");
               end if;
               Self.Next := Self.Next + 1;
               Available := True;
               return;
            end if;
         end if;

         if Self.At_End then
            Available := Has_Data;
            return;
         end if;

         if Self.Is_Stdin then
            if not Context.Try_Read_Standard_Input (Self.Buffer, Self.Last) then
               Ok := False;
               return;
            end if;
            Self.At_End := Self.Last < Self.Buffer'First;
         else
            Inputs.Read (Self.File, Self.Buffer, Self.Last, Outcome);
            Self.At_End := Outcome = Inputs.Read_End;
            if Outcome = Inputs.Read_Failed then
               Ok := False;
               return;
            end if;
         end if;
         Self.Next := Self.Buffer'First;
      end loop;
   end Next;
end Posix_Tools.Commands.Line_Readers;
