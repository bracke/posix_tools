separate (Regression_Registry)
procedure Self_Test is
   Visited : Natural := 0;
   LF      : constant Character := Character'Val (10);

   procedure Visit (Reference : String) is
      pragma Unreferenced (Reference);
   begin
      Visited := Visited + 1;
   end Visit;

   procedure Expect
     (References     : String;
      Expected_Count : Natural;
      Expected_Empty : Boolean) is
      Count     : Natural;
      Has_Empty : Boolean;
   begin
      Visited := 0;
      For_Each_Test_Reference
        (References, Visit'Access, Count, Has_Empty);
      if Count /= Expected_Count
        or else Visited /= Expected_Count
        or else Has_Empty /= Expected_Empty
      then
         raise Program_Error with
           "regression reference parser self-test failed";
      end if;
   end Expect;

   procedure Expect_Content
     (Content : String;
      Valid   : Boolean)
   is
      Parsed : Row_Vectors.Vector;
      Error  : Unbounded_String;
   begin
      Parse_Content (Content, Parsed, Error);
      if (Length (Error) = 0) /= Valid then
         raise Program_Error with
           "regression registry schema self-test failed";
      end if;
   end Expect_Content;

   function Four_Digits (Value : Positive) return String is
      Image  : constant String := Trimmed (Positive'Image (Value));
      Result : String (1 .. 4) := [others => '0'];
   begin
      Result (Result'Last - Image'Length + 1 .. Result'Last) := Image;
      return Result;
   end Four_Digits;

   function Registry_Row (Value : Positive) return String is
     ("REG-TEST-" & Four_Digits (Value)
      & ",command,summary,basic:test");
begin
   Expect ("one; two", 2, False);
   Expect ("one;", 1, True);
   Expect (";", 0, True);
   Expect (" ", 0, True);

   Expect_Content
     ("id,command,summary,test" & LF & Registry_Row (1), True);
   Expect_Content ("wrong,header" & LF & Registry_Row (1), False);
   Expect_Content
     ("id,command,summary,test" & LF
      & "REG-TEST-0001,command,summary",
      False);
   Expect_Content
     ("id,command,summary,test" & LF
      & "REG-BAD,command,summary,basic:test",
      False);
   Expect_Content
     ("id,command,summary,test" & LF
      & "REG-A--0001,command,summary,basic:test",
      False);
   Expect_Content
     ("id,command,summary,test" & LF
      & "REG-TEST-0001,,summary,basic:test",
      False);
   Expect_Content
     ("id,command,summary,test" & LF
      & "REG-TEST-0001,command,,basic:test",
      False);
   Expect_Content
     ("id,command,summary,test" & LF
      & "REG-TEST-0001,command,summary,basic:test;",
      False);
   Expect_Content
     ("id,command,summary,test" & LF
      & Registry_Row (1) & LF & Registry_Row (1),
      False);
   declare
      Content : Unbounded_String :=
        To_Unbounded_String ("id,command,summary,test" & LF);
   begin
      for Value in 1 .. 257 loop
         Append (Content, Registry_Row (Value) & LF);
      end loop;
      Expect_Content (To_String (Content), False);
   end;
end Self_Test;
