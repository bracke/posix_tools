package body Posix_Tools.Text.UTF_8
  with SPARK_Mode => On
is
   procedure Reset (Self : out Decoder) is
   begin
      Self.Expected_Continuations := 0;
      Self.Accumulator := 0;
      Self.Minimum_Code_Point := 0;
   end Reset;

   procedure Decode
     (Self       : in out Decoder;
      Byte       : Natural;
      Status     : out Decode_Status;
      Code_Point : out Long_Long_Integer)
   is
   begin
      Status := Need_More;
      Code_Point := 0;

      if Self.Expected_Continuations = 0 then
         if Byte <= 16#7F# then
            Status := Complete;
            Code_Point := Long_Long_Integer (Byte);
         elsif Byte in 16#C2# .. 16#DF# then
            Self.Expected_Continuations := 1;
            Self.Accumulator := Long_Long_Integer (Byte mod 32);
            Self.Minimum_Code_Point := 16#80#;
         elsif Byte in 16#E0# .. 16#EF# then
            Self.Expected_Continuations := 2;
            Self.Accumulator := Long_Long_Integer (Byte mod 16);
            Self.Minimum_Code_Point := 16#800#;
         elsif Byte in 16#F0# .. 16#F4# then
            Self.Expected_Continuations := 3;
            Self.Accumulator := Long_Long_Integer (Byte mod 8);
            Self.Minimum_Code_Point := 16#10000#;
         else
            Reset (Self);
            Status := Invalid;
         end if;
      elsif Byte not in 16#80# .. 16#BF# then
         Reset (Self);
         Status := Invalid;
      else
         pragma Assert (Self.Accumulator >= 0);
         Self.Accumulator :=
           Self.Accumulator * 64 + Long_Long_Integer (Byte mod 64);
         Self.Expected_Continuations := Self.Expected_Continuations - 1;

         if Self.Expected_Continuations = 0 then
            if Self.Accumulator < Self.Minimum_Code_Point
              or else Self.Accumulator in 16#D800# .. 16#DFFF#
              or else Self.Accumulator > 16#10FFFF#
            then
               Reset (Self);
               Status := Invalid;
            else
               Code_Point := Self.Accumulator;
               Reset (Self);
               Status := Complete;
            end if;
         end if;
      end if;
   end Decode;

   procedure Finish
     (Self   : in out Decoder;
      Status : out Decode_Status)
   is
   begin
      if Self.Expected_Continuations = 0 then
         Status := Complete;
      else
         Reset (Self);
         Status := Invalid;
      end if;
   end Finish;
end Posix_Tools.Text.UTF_8;
