with Ada.Streams;
with Posix_Tools.Numbers;
private with Hostkit.Descriptors;

package Posix_Tools.Host_Adapters.Temporary_Storage is
   use type Ada.Streams.Stream_Element_Offset;

   type Store is limited private;

   function Create (Self : in out Store; Max_Bytes : Posix_Tools.Numbers.Count) return Boolean;

   function Append
     (Self   : in out Store;
      Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return Boolean
     with Pre => Last < Buffer'First or else Last in Buffer'Range;

   function Prepare_For_Read (Self : in out Store) return Boolean;

   function Read
     (Self   : in out Store;
      First  : Posix_Tools.Numbers.Count;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset) return Boolean
     with
       Pre => Buffer'First > Ada.Streams.Stream_Element_Offset'First,
       Post =>
         (if Read'Result then
            Last < Buffer'First or else Last in Buffer'Range
          else
            Last < Buffer'First);

   function Size (Self : Store) return Posix_Tools.Numbers.Count;

   procedure Cleanup (Self : in out Store);

private
   type Store is limited record
      Directory : String (1 .. 512);
      Directory_Last : Natural := 0;
      Path : String (1 .. 640);
      Path_Last : Natural := 0;
      File : Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Invalid;
      Max_Size : Posix_Tools.Numbers.Count := 0;
      Current_Size : Posix_Tools.Numbers.Count := 0;
      Reading : Boolean := False;
      Read_Position : Posix_Tools.Numbers.Count := 1;
   end record;
end Posix_Tools.Host_Adapters.Temporary_Storage;
