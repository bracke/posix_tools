with Ada.Streams;
with Posix_Tools.Numbers;
private with Ada.Finalization;
private with Ada.Strings.Unbounded;
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

   --  Try to close and remove every resource owned by Self.  A failed
   --  removal remains recorded so a later call can retry it.
   function Try_Cleanup (Self : in out Store) return Boolean;

private
   type Store is new Ada.Finalization.Limited_Controlled with record
      Directory : Ada.Strings.Unbounded.Unbounded_String;
      Path : Ada.Strings.Unbounded.Unbounded_String;
      File : Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Invalid;
      Max_Size : Posix_Tools.Numbers.Count := 0;
      Current_Size : Posix_Tools.Numbers.Count := 0;
      Reading : Boolean := False;
      Read_Position : Posix_Tools.Numbers.Count := 1;
   end record;

   overriding procedure Finalize (Self : in out Store);
end Posix_Tools.Host_Adapters.Temporary_Storage;
