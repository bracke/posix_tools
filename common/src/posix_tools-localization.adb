with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Localization is
   use type Messages.Result.Render_Status;

   function Catalog_Path return String is
   begin
      if Posix_Tools.Host_Adapters.File_System.Exists ("common/messages/posix_tools.catalog") then
         return "common/messages/posix_tools.catalog";
      elsif Posix_Tools.Host_Adapters.File_System.Exists ("../common/messages/posix_tools.catalog") then
         return "../common/messages/posix_tools.catalog";
      elsif Posix_Tools.Host_Adapters.File_System.Exists ("../../common/messages/posix_tools.catalog") then
         return "../../common/messages/posix_tools.catalog";
      end if;

      return "common/messages/posix_tools.catalog";
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
              Locale    => (if Locale = "" then "en" else Locale),
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
              Locale    => (if Locale = "" then "en" else Locale),
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
