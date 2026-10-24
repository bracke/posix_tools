package body Posix_Tools.Text.Natural_Order
  with SPARK_Mode => On
is
   function Folded (Item : Character; Fold_Case : Boolean) return Character is
     (if Fold_Case and then Item in 'A' .. 'Z'
      then Character'Val (Character'Pos (Item) + 32)
      else Item);

   function Is_Digit (Item : Character) return Boolean is (Item in '0' .. '9');

   --  The run of digits in Text starting at offset From: Last is the offset of
   --  its last digit, Significant that of its first digit other than a leading
   --  zero, or of its last digit when it is all zeros.
   procedure Digit_Run (Text : String; From : Natural; Significant, Last : out Natural)
     with
       Pre  => From < Text'Length,
       Post => From <= Significant and then Significant <= Last and then Last < Text'Length;

   procedure Digit_Run (Text : String; From : Natural; Significant, Last : out Natural) is
   begin
      Last := From;

      while Last < Text'Length - 1 and then Is_Digit (Text (Text'First + Last + 1)) loop
         pragma Loop_Invariant (From <= Last and then Last < Text'Length - 1);
         pragma Loop_Variant (Increases => Last);
         Last := Last + 1;
      end loop;

      Significant := From;

      while Significant < Last and then Text (Text'First + Significant) = '0' loop
         pragma Loop_Invariant (From <= Significant and then Significant < Last);
         pragma Loop_Variant (Increases => Significant);
         Significant := Significant + 1;
      end loop;
   end Digit_Run;

   function Less (Left, Right : String; Fold_Case : Boolean := False) return Boolean is
      I : Natural := 0;
      J : Natural := 0;
   begin
      while I < Left'Length and then J < Right'Length loop
         pragma Loop_Invariant (I < Left'Length and then J < Right'Length);
         pragma Loop_Variant (Increases => I);

         declare
            L : constant Character := Left (Left'First + I);
            R : constant Character := Right (Right'First + J);
         begin
            if Is_Digit (L) and then Is_Digit (R) then
               declare
                  L_Significant, L_Last, R_Significant, R_Last : Natural;
               begin
                  Digit_Run (Left, I, L_Significant, L_Last);
                  Digit_Run (Right, J, R_Significant, R_Last);

                  --  Without leading zeros, the longer run is the larger number.
                  if L_Last - L_Significant /= R_Last - R_Significant then
                     return L_Last - L_Significant < R_Last - R_Significant;
                  end if;

                  for K in 0 .. L_Last - L_Significant loop
                     pragma Loop_Invariant (L_Significant + K <= L_Last and then R_Significant + K <= R_Last);

                     if Left (Left'First + L_Significant + K) /= Right (Right'First + R_Significant + K) then
                        return Left (Left'First + L_Significant + K) < Right (Right'First + R_Significant + K);
                     end if;
                  end loop;

                  I := L_Last + 1;
                  J := R_Last + 1;
               end;
            elsif Folded (L, Fold_Case) /= Folded (R, Fold_Case) then
               return Folded (L, Fold_Case) < Folded (R, Fold_Case);
            else
               I := I + 1;
               J := J + 1;
            end if;
         end;
      end loop;

      if I < Left'Length then
         return False;
      elsif J < Right'Length then
         return True;
      else
         return Left < Right;
      end if;
   end Less;
end Posix_Tools.Text.Natural_Order;
