package Posix_Tools.Text.UTF_8
  with SPARK_Mode => On
is
   type Decode_Status is (Complete, Need_More, Invalid);

   type Decoder is private;

   function Is_Initial (Self : Decoder) return Boolean;

   procedure Decode
     (Self       : in out Decoder;
      Byte       : Natural;
      Status     : out Decode_Status;
      Code_Point : out Long_Long_Integer)
     with
       Post =>
         (if Status /= Complete then Code_Point = 0)
         and then
           (if Status /= Need_More then Is_Initial (Self))
         and then
           (if Status = Need_More then not Is_Initial (Self))
         and then
           (if Status = Complete then
              Code_Point in 0 .. 16#10FFFF#
              and then not (Code_Point in 16#D800# .. 16#DFFF#))
         and then
           (if Is_Initial (Self'Old) and then Byte <= 16#7F# then
              Status = Complete
              and then Code_Point = Long_Long_Integer (Byte)
              and then Is_Initial (Self))
         and then
           (if Is_Initial (Self'Old)
             and then not (Byte <= 16#7F#)
             and then not (Byte in 16#C2# .. 16#F4#)
            then
              Status = Invalid
              and then Is_Initial (Self))
         and then
           (if Is_Initial (Self'Old) and then Byte in 16#C2# .. 16#F4# then
              Status = Need_More
              and then Code_Point = 0
              and then not Is_Initial (Self));

   procedure Finish
     (Self   : in out Decoder;
      Status : out Decode_Status)
     with
       Post =>
         Is_Initial (Self)
         and then
           (if Is_Initial (Self'Old) then
              Status = Complete
            else
              Status = Invalid);

private
   type Decoder is record
      Expected_Continuations : Natural := 0;
      Accumulator            : Long_Long_Integer := 0;
      Minimum_Code_Point     : Long_Long_Integer := 0;
   end record
     with Type_Invariant =>
       Decoder.Expected_Continuations <= 3
       and then Decoder.Accumulator >= 0
       and then
         (if Decoder.Expected_Continuations = 0 then
            Decoder.Accumulator = 0
            and then Decoder.Minimum_Code_Point = 0)
       and then
         (if Decoder.Expected_Continuations = 1 then
            Decoder.Accumulator <= 16#4FFF#)
       and then
         (if Decoder.Expected_Continuations = 2 then
            Decoder.Accumulator <= 16#13F#)
       and then
         (if Decoder.Expected_Continuations = 3 then
            Decoder.Accumulator <= 16#4#);

   function Is_Initial (Self : Decoder) return Boolean is
     (Self.Expected_Continuations = 0);
end Posix_Tools.Text.UTF_8;
