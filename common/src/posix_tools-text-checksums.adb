package body Posix_Tools.Text.Checksums
  with SPARK_Mode => On
is
   Polynomial : constant Interfaces.Unsigned_32 := 16#04C11DB7#;

   type CRC_Table_Type is array (Interfaces.Unsigned_32 range 0 .. 255) of Interfaces.Unsigned_32;
   function Build_CRC_Table return CRC_Table_Type;

   function Build_CRC_Table return CRC_Table_Type is
      use type Interfaces.Unsigned_32;
      Result : CRC_Table_Type := [others => 0];
   begin
      for Byte in Result'Range loop
         Result (Byte) := Interfaces.Shift_Left (Byte, 24);
         for Bit in 1 .. 8 loop
            if (Result (Byte) and 16#80000000#) /= 0 then
               Result (Byte) := Interfaces.Shift_Left (Result (Byte), 1) xor Polynomial;
            else
               Result (Byte) := Interfaces.Shift_Left (Result (Byte), 1);
            end if;
         end loop;
      end loop;
      return Result;
   end Build_CRC_Table;

   CRC_Table : constant CRC_Table_Type := Build_CRC_Table;

   type CRC_Tables_Type is array
     (Natural range 0 .. 7, Interfaces.Unsigned_32 range 0 .. 255)
     of Interfaces.Unsigned_32;
   function Build_CRC_Tables return CRC_Tables_Type;

   function Advance_CRC
     (CRC  : Interfaces.Unsigned_32;
      Byte : Interfaces.Unsigned_32) return Interfaces.Unsigned_32;
   pragma Inline_Always (Advance_CRC);

   function Advance_CRC
     (CRC  : Interfaces.Unsigned_32;
      Byte : Interfaces.Unsigned_32) return Interfaces.Unsigned_32
   is
      use type Interfaces.Unsigned_32;
      Index : constant Interfaces.Unsigned_32 :=
        Interfaces.Shift_Right (CRC, 24) xor Byte;
   begin
      return Interfaces.Shift_Left (CRC, 8) xor CRC_Table (Index);
   end Advance_CRC;

   function Build_CRC_Tables return CRC_Tables_Type is
      Result : CRC_Tables_Type := [others => [others => 0]];
   begin
      for Byte in CRC_Table'Range loop
         Result (0, Byte) := CRC_Table (Byte);
         for Slice in 1 .. 7 loop
            Result (Slice, Byte) := Advance_CRC (Result (Slice - 1, Byte), 0);
         end loop;
      end loop;
      return Result;
   end Build_CRC_Tables;

   CRC_Tables : constant CRC_Tables_Type := Build_CRC_Tables;

   function POSIX_Cksum_CRC_32 (Text : String) return Interfaces.Unsigned_32 is
      State : POSIX_Cksum_State := Initial_POSIX_Cksum_State;
   begin
      Update (State, Text);
      return Digest (State);
   end POSIX_Cksum_CRC_32;

   function Initial_POSIX_Cksum_State return POSIX_Cksum_State is
     (CRC => 0, Byte_Count => 0);

   procedure Update (State : in out POSIX_Cksum_State; Text : String) is
      CRC : Interfaces.Unsigned_32 := State.CRC;
   begin
      for Ch of Text loop
         CRC := Advance_CRC
           (CRC, Interfaces.Unsigned_32 (Character'Pos (Ch)));
      end loop;
      State.CRC := CRC;
      State.Byte_Count := State.Byte_Count + Posix_Tools.Numbers.Count (Text'Length);
   end Update;

   procedure Update
     (State  : in out POSIX_Cksum_State;
      Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset)
   is
      use type Interfaces.Unsigned_32;
      CRC : Interfaces.Unsigned_32 := State.CRC;
      I   : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Last < Buffer'First then
         return;
      end if;

      --  Advance eight input bytes at once. Each table represents one more
      --  zero-byte advance of the same POSIX polynomial, removing the serial
      --  dependency between the eight ordinary byte updates.
      while I <= Last and then Last - I > 7 loop
         pragma Loop_Invariant (I in Buffer'Range and then I <= Last);
         CRC :=
           CRC_Tables
             (7,
              Interfaces.Shift_Right (CRC, 24)
                xor Interfaces.Unsigned_32 (Buffer (I)))
           xor CRC_Tables
             (6,
              (Interfaces.Shift_Right (CRC, 16) and 16#FF#)
                xor Interfaces.Unsigned_32 (Buffer (I + 1)))
           xor CRC_Tables
             (5,
              (Interfaces.Shift_Right (CRC, 8) and 16#FF#)
                xor Interfaces.Unsigned_32 (Buffer (I + 2)))
           xor CRC_Tables
             (4,
              (CRC and 16#FF#)
                xor Interfaces.Unsigned_32 (Buffer (I + 3)))
           xor CRC_Tables (3, Interfaces.Unsigned_32 (Buffer (I + 4)))
           xor CRC_Tables (2, Interfaces.Unsigned_32 (Buffer (I + 5)))
           xor CRC_Tables (1, Interfaces.Unsigned_32 (Buffer (I + 6)))
           xor CRC_Tables (0, Interfaces.Unsigned_32 (Buffer (I + 7)));
         I := I + 8;
      end loop;

      while I <= Last loop
         pragma Loop_Invariant (I in Buffer'Range and then I <= Last);
         CRC := Advance_CRC
           (CRC, Interfaces.Unsigned_32 (Buffer (I)));
         exit when I = Last;
         I := I + 1;
      end loop;
      State.CRC := CRC;
      State.Byte_Count :=
        State.Byte_Count
        + Posix_Tools.Numbers.Count (Last - Buffer'First + 1);
   end Update;

   function Digest (State : POSIX_Cksum_State) return Interfaces.Unsigned_32 is
      use type Interfaces.Unsigned_32;
      CRC          : Interfaces.Unsigned_32 := State.CRC;
      Length_Value : Posix_Tools.Numbers.Count := State.Byte_Count;
   begin
      while Length_Value /= 0 loop
         pragma Loop_Variant (Decreases => Length_Value);

         CRC := Advance_CRC (CRC, Interfaces.Unsigned_32 (Length_Value mod 256));
         Length_Value := Length_Value / 256;
      end loop;

      return not CRC;
   end Digest;

   function Length (State : POSIX_Cksum_State) return Posix_Tools.Numbers.Count is
     (State.Byte_Count);
end Posix_Tools.Text.Checksums;
