private with Hostkit.Descriptors;

--  An output file kept open across writes, for commands that write a stream
--  to files as it arrives (tee). Opening once matters for FIFOs and devices,
--  where every open is an event the other side sees.
package Posix_Tools.Host_Adapters.Output_Files is
   type Output_File is limited private;

   function Is_Open (File : Output_File) return Boolean;

   --  Opens Path for writing, creating it when absent; truncates it unless
   --  Append_Mode, which writes every byte at the end.
   procedure Open
     (File        : in out Output_File;
      Path        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean)
   with Post => Ok = Is_Open (File);

   --  Writes all of Text; False when the host refused part of it.
   procedure Write (File : Output_File; Text : String; Ok : out Boolean)
   with Pre => Is_Open (File);

   --  Closes File; False when the host reported the close as failing.
   procedure Close (File : in out Output_File; Ok : out Boolean)
   with Post => not Is_Open (File);
private
   type Output_File is limited record
      Descriptor : Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Invalid;
   end record;
end Posix_Tools.Host_Adapters.Output_Files;
