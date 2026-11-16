with Ada.Streams;
with Interfaces;
with Posix_Tools.Numbers;

package Posix_Tools.Text.Checksums
  with SPARK_Mode => On
is
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;

   type POSIX_Cksum_State is private;

   function Initial_POSIX_Cksum_State return POSIX_Cksum_State;
   function Length
     (State : POSIX_Cksum_State) return Posix_Tools.Numbers.Count;
   function Can_Update
     (State  : POSIX_Cksum_State;
      Amount : Posix_Tools.Numbers.Count) return Boolean is
     (Length (State) <= Posix_Tools.Numbers.Count'Last - Amount);

   procedure Update (State : in out POSIX_Cksum_State; Text : String)
     with Pre =>
       Can_Update
         (State, Posix_Tools.Numbers.Count (Text'Length));
   procedure Update
     (State  : in out POSIX_Cksum_State;
      Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset)
     with Pre =>
       Last < Buffer'First
       or else
         (Buffer'First >= 0
          and then Last < Ada.Streams.Stream_Element_Offset'Last
          and then Last in Buffer'Range
          and then Can_Update
            (State,
             Posix_Tools.Numbers.Count
               (Last - Buffer'First + 1)));
   function Digest (State : POSIX_Cksum_State) return Interfaces.Unsigned_32;

   function POSIX_Cksum_CRC_32 (Text : String) return Interfaces.Unsigned_32;

private
   type POSIX_Cksum_State is record
      CRC        : Interfaces.Unsigned_32 := 0;
      Byte_Count : Posix_Tools.Numbers.Count := 0;
   end record;
end Posix_Tools.Text.Checksums;
