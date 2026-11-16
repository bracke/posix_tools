separate (Metadata_Checks.Catalog_Defaults)
procedure Self_Test is
   function Issue (Catalog : String; Raw : String) return String is
      Result : constant Validation_Result := Validate_Defaults (Catalog, Raw);
   begin
      return (if Result.Valid then "" else To_String (Result.Detail));
   end Issue;

   function Source (Statements : String) return String is
     ("function Template (Key : String) return String is" & LF
      & "begin" & LF
      & Statements & LF
      & "else" & LF
      & "   return """";" & LF
      & "end if;" & LF
      & "end Template;");

   Defaults : constant String :=
     "if Key = ""last"" then" & LF
     & "         return" & LF
     & "           ""final text"";";
   Two_Defaults : constant String :=
     "if Key = ""first"" then return ""first text"";" & LF
     & "elsif Key = ""last"" then return ""final text"";";
   CR : constant Character := Character'Val (13);
begin
   if Issue
     ("default_locale = en" & LF
      & "en.last = final text", Source (Defaults)) /= ""
     or else Issue
       ("default_locale = en" & LF
        & "en.last = final text" & LF
        & "da.last = sidste tekst",
        Source (Defaults)) /= ""
     or else Issue
       ("default_locale = en" & LF
        & "en.last = changed text", Source (Defaults)) /= "last"
     or else Issue
       ("default_locale = en" & LF
        & "en.first = first text" & LF & "en.last = changed text",
        Source
          ("if Key = ""first"" then" & LF
           & "         return" & LF
           & "           ""first text"";")) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          (Defaults & LF
           & "elsif Key = ""last"" then return ""final text"";")) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          (Defaults & LF
           & "elsif Key = ""extra"" then return ""extra text"";")) /= "extra"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          ("if Enabled and then Key = ""last"" then" & LF
           & "   return ""final text"";")) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          ("--  if Key = ""last"" then return ""final text"";")) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          ("Text := ""if Key = """"last"""" then return """"final text"""";"";"))
       /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          ("if False then" & LF
           & "   if Key = ""last"" then return ""final text"";" & LF
           & "   end if;" & LF
           & "end if;")) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        "function Unused (Key : String) return String is" & LF
        & "begin" & LF
        & Defaults & LF
        & "end Unused;" & LF
        & Source ("return """";")) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          ("Ignored := (if Enabled then 1 else 0);" & LF
           & Defaults)) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          ("case Enabled is" & LF
           & "   when True =>" & LF
           & "      " & Defaults & LF
           & "   when False => null;" & LF
           & "end case;")) /= "last"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        Source
          (Defaults & LF
           & "elsif Enabled then return ""uncatalogued"";")) /= "Template fallback"
     or else Issue
       ("default_locale = en" & LF & "en.last = final text",
        "function Template (Key : String) return String is" & LF
        & "begin" & LF
        & Defaults & LF
        & "else" & LF
        & "   return --  misleading """"" & LF
        & "     ""uncatalogued"";" & LF
        & "end if;" & LF
        & "end Template;") /= "Template fallback"
     or else Issue
       ("en.last = final text", Source (Defaults)) /= "default_locale"
     or else Issue
       ("default_locale = en" & LF
        & "default_locale = en" & LF
        & "en.last = final text",
        Source (Defaults)) = ""
     or else Issue
       ("default_locale = en" & LF
        & "en.last = final text" & LF
        & "da.last = sidste tekst" & LF
        & "da.last = gentaget tekst",
        Source (Defaults)) /= "da.last"
     or else Issue
       ("default_locale = en" & LF
        & "en.first = first text" & LF
        & "en.last = final text" & LF
        & "da.first = foerste tekst",
        Source (Two_Defaults)) /= "da.last"
     or else Issue
       ("default_locale = en" & LF
        & "en.last = final text" & LF
        & "da.last = sidste tekst" & LF
        & "da.extra = ekstra tekst",
        Source (Defaults)) /= "da.extra"
     or else Issue
       ("default_locale = en" & CR & LF
        & "en.last = final text" & CR & LF,
        Source (Defaults)) /= ""
     or else Issue
       ("",
        "function Template (Key : String) return String is" & LF
        & "begin" & LF
        & "   return """";" & LF
        & "end Template;") = ""
     or else Issue
       ("en. = empty", Source ("if Key = """" then return ""empty"";")) = ""
     or else Issue
       ("en.bad key = text",
        Source ("if Key = ""bad key"" then return ""text"";")) = ""
     or else Issue
       ("en.good = text",
        Source ("if Key = """" then return ""text"";")) = ""
     or else Issue
       ("en.last=final text", Source (Defaults)) = ""
     or else Issue
       (" en.last = final text", Source (Defaults)) = ""
     or else Issue
       ("en.last = final text" & LF & "not a catalog entry",
        Source (Defaults)) = ""
   then
      Tooling_Checks.Fail
        ("catalog-default semantic parser self-test failed");
   end if;
end Self_Test;
