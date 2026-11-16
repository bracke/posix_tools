separate (Metadata_Checks.Warning_Policy)
procedure Self_Test is
begin
   if Rejects_Warnings
     ("-- for Default_Switches (""Ada"") use (""-gnatwe"");")
     or else Rejects_Warnings
       ("for Description use ""for Default_Switches (""""Ada"""") use "
        & "(""""-gnatwe"""");"";")
     or else not Rejects_Warnings
       ("FOR Default_Switches(""ADA"") USE (""-gnatwa"", ""-gnatwe"");")
     or else Rejects_Warnings
       ("for Default_Switches (""Ada"") use (""-gnatwe"");"
        & "for Default_Switches (""Ada"") use (""-O2"");")
     or else Rejects_Warnings
       ("for Default_Switches (""Ada"") use (""-gnatwe"", ""-gnatws"");")
     or else Rejects_Warnings
       ("for Default_Switches (""Ada"") use (""-O2"" & ""-gnatwe"");")
     or else Rejects_Warnings
       ("for Default_Switches (""Ada"") use Switches & (""-gnatwe"");")
   then
      Tooling_Checks.Fail ("warning-policy parser self-test failed");
   end if;
end Self_Test;
