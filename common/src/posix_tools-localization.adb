with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Locale_Fields;

package body Posix_Tools.Localization is
   use type Messages.Result.Render_Status;

   function Catalog_Path return String is
   begin
      return Posix_Tools.Text.Locale_Fields.Catalog_Path
        (Here        =>
           Posix_Tools.Host_Adapters.File_System.Exists ("common/messages/posix_tools.catalog"),
         Parent      =>
           Posix_Tools.Host_Adapters.File_System.Exists ("../common/messages/posix_tools.catalog"),
         Grandparent =>
           Posix_Tools.Host_Adapters.File_System.Exists ("../../common/messages/posix_tools.catalog"));
   end Catalog_Path;

   function Text
     (Locale  : String;
      Key     : String;
      Default : String) return String
   is
      Runtime : Messages.Runtime.Instance;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Initialize (Runtime, Catalog_Path);
      if not Messages.Runtime.Is_Valid (Runtime) then
         return Default;
      end if;

      declare
         Rendered : constant Messages.Result.Render_Result :=
           Messages.Runtime.Render
             (Item      => Runtime,
              Locale    => Posix_Tools.Text.Locale_Fields.Effective_Locale (Locale),
              Key       => Key,
              Arguments => Args);
      begin
         if Rendered.Status = Messages.Result.Success then
            return Messages.Result.Output_Text (Rendered.Text);
         else
            return Default;
         end if;
      end;
   end Text;

   function Text_1
     (Locale  : String;
      Key     : String;
      Name    : String;
      Value   : String;
      Default : String) return String
   is
      Runtime : Messages.Runtime.Instance;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Initialize (Runtime, Catalog_Path);
      if not Messages.Runtime.Is_Valid (Runtime) then
         return Default;
      end if;

      Messages.Arguments.Set (Args, Name, Value);
      declare
         Rendered : constant Messages.Result.Render_Result :=
           Messages.Runtime.Render
             (Item      => Runtime,
              Locale    => Posix_Tools.Text.Locale_Fields.Effective_Locale (Locale),
              Key       => Key,
              Arguments => Args);
      begin
         if Rendered.Status = Messages.Result.Success then
            return Messages.Result.Output_Text (Rendered.Text);
         else
            return Default;
         end if;
      end;
   end Text_1;
end Posix_Tools.Localization;
