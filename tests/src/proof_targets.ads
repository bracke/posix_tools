generic
   with procedure Prove_Target
     (Gnatprove : String;
      Label     : String;
      Unit_Name : String;
      Mode      : String;
      Level     : String := "1");
procedure Proof_Targets (Gnatprove : String);
