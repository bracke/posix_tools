with Hostkit.Descriptors;

package body Posix_Tools.Host_Adapters.Streams is
   function Write_All
     (Target : Hostkit.Descriptors.Descriptor;
      Bytes  : Ada.Streams.Stream_Element_Array) return Boolean
   is
      use Hostkit.Descriptors;

      First   : Ada.Streams.Stream_Element_Offset := Bytes'First;
      Last    : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;
   begin
      while First <= Bytes'Last loop
         Outcome := Write (Target, Bytes (First .. Bytes'Last), Last);
         case Outcome is
            when Transfer_Ok =>
               if Last < First then
                  return False;
               end if;

               First := Last + 1;

            when Transfer_Interrupted =>
               null;

            when others =>
               return False;
         end case;
      end loop;

      return True;
   exception
      when others =>
         return False;
   end Write_All;

   function Write_Text (Target : Hostkit.Descriptors.Descriptor; Text : String) return Boolean is
   begin
      if Text = "" then
         return True;
      end if;

      declare
         Bytes : constant Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Text'Length))
           with Import, Address => Text (Text'First)'Address;
      begin
         return Write_All (Target, Bytes);
      end;
   end Write_Text;

   procedure Read_Standard_Input
     (Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      use Hostkit.Descriptors;

      Outcome : Transfer_Outcome;
   begin
      loop
         Outcome := Read (Standard_Input, Buffer, Last);
         case Outcome is
            when Transfer_Ok =>
               return;

            when Transfer_End_Of_File =>
               Last := Buffer'First - 1;
               return;

            when Transfer_Interrupted =>
               null;

            when others =>
               Last := Buffer'First - 1;
               return;
         end case;
      end loop;
   end Read_Standard_Input;

   function Try_Read_Standard_Input
     (Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
   is
   begin
      loop
         case Hostkit.Descriptors.Read (Hostkit.Descriptors.Standard_Input, Buffer, Last) is
            when Hostkit.Descriptors.Transfer_Ok =>
               return True;

            when Hostkit.Descriptors.Transfer_End_Of_File =>
               Last := Buffer'First - 1;
               return True;

            when Hostkit.Descriptors.Transfer_Interrupted =>
               null;

            when others =>
               Last := Buffer'First - 1;
               return False;
         end case;
      end loop;
   exception
      when others =>
         --  intentional terminal exception barrier
         Last := Buffer'First - Ada.Streams.Stream_Element_Offset (1);
         return False;
   end Try_Read_Standard_Input;

   procedure Write_Standard_Error_Line (Text : String; Ok : out Boolean) is
   begin
      Ok := Write_Text (Hostkit.Descriptors.Standard_Error, Text);
      if Ok then
         Ok := Write_Text
           (Hostkit.Descriptors.Standard_Error, "" & Character'Val (10));
      end if;
   end Write_Standard_Error_Line;

   function Write_Standard_Output (Text : String) return Boolean is
   begin
      return Write_Text (Hostkit.Descriptors.Standard_Output, Text);
   end Write_Standard_Output;

   function Write_Standard_Output
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return Boolean
   is
   begin
      return Last < Buffer'First
        or else Write_All
          (Hostkit.Descriptors.Standard_Output,
           Buffer (Buffer'First .. Last));
   end Write_Standard_Output;

   function Write_Standard_Error (Text : String) return Boolean is
   begin
      return Write_Text (Hostkit.Descriptors.Standard_Error, Text);
   end Write_Standard_Error;

   procedure Write_Standard_Output_Line (Text : String; Ok : out Boolean) is
   begin
      Ok := Write_Text (Hostkit.Descriptors.Standard_Output, Text);
      if Ok then
         Ok := Write_Text
           (Hostkit.Descriptors.Standard_Output, "" & Character'Val (10));
      end if;
   end Write_Standard_Output_Line;
end Posix_Tools.Host_Adapters.Streams;
