with Ada.Text_IO;
with Ada.Text_IO.Text_Streams;

package body Posix_Tools.Host_Adapters.Streams is
   use type Ada.Streams.Stream_Element_Offset;

   procedure Read_Standard_Input
     (Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
   begin
      Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Input).all.Read (Buffer, Last);
   end Read_Standard_Input;

   function Try_Read_Standard_Input
     (Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
   is
   begin
      Read_Standard_Input (Buffer, Last);
      return True;
   exception
      when others =>
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
   end Try_Read_Standard_Input;

   procedure Write_Standard_Error_Line (Text : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Text);
   end Write_Standard_Error_Line;

   function Write_Standard_Output (Text : String) return Boolean is
      Buffer : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
      Target : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Text = "" then
         return True;
      end if;

      for Ch of Text loop
         Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Ch));
         Target := Target + Ada.Streams.Stream_Element_Offset (1);
      end loop;

      Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Output).all.Write (Buffer);
      return True;
   exception
      when others =>
         return False;
   end Write_Standard_Output;

   procedure Write_Standard_Output_Line (Text : String; Ok : out Boolean) is
   begin
      Ada.Text_IO.Put_Line (Text);
      Ok := True;
   exception
      when others =>
         Ok := False;
   end Write_Standard_Output_Line;
end Posix_Tools.Host_Adapters.Streams;
