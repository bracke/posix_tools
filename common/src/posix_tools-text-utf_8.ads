package Posix_Tools.Text.UTF_8
  with SPARK_Mode => On
is
   type Decode_Status is (Complete, Need_More, Invalid);

   type Decoder is private;

   procedure Decode
     (Self       : in out Decoder;
      Byte       : Natural;
      Status     : out Decode_Status;
      Code_Point : out Long_Long_Integer);

   procedure Finish
     (Self   : in out Decoder;
      Status : out Decode_Status);

private
   type Decoder is record
      Expected_Continuations : Natural := 0;
      Accumulator            : Long_Long_Integer := 0;
      Minimum_Code_Point     : Long_Long_Integer := 0;
   end record;
end Posix_Tools.Text.UTF_8;
