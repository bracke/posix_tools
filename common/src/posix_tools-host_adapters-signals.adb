with Hostkit.Signals;

package body Posix_Tools.Host_Adapters.Signals is
   function To_Hostkit_Signal (Item : Signal) return Hostkit.Signals.Signal is
   begin
      case Item is
         when Interrupt =>
            return Hostkit.Signals.Signal_Interrupt;
      end case;
   end To_Hostkit_Signal;

   function From_Hostkit_Disposition (Value : Hostkit.Signals.Disposition) return Disposition is
   begin
      case Value is
         when Hostkit.Signals.Disposition_Default =>
            return Default_Disposition;
         when Hostkit.Signals.Disposition_Ignore =>
            return Ignore_Disposition;
         when others =>
            return Unknown_Disposition;
      end case;
   end From_Hostkit_Disposition;

   function To_Hostkit_Disposition (Value : Disposition) return Hostkit.Signals.Disposition is
   begin
      case Value is
         when Default_Disposition =>
            return Hostkit.Signals.Disposition_Default;
         when Ignore_Disposition =>
            return Hostkit.Signals.Disposition_Ignore;
         when Unknown_Disposition =>
            return Hostkit.Signals.Disposition_Default;
      end case;
   end To_Hostkit_Disposition;

   function Is_Supported (Item : Signal) return Boolean is
   begin
      return Hostkit.Signals.Is_Supported (To_Hostkit_Signal (Item));
   end Is_Supported;

   function Current_Disposition (Item : Signal; Value : out Disposition) return Boolean is
      Host_Value : Hostkit.Signals.Disposition;
   begin
      if not Hostkit.Signals.Current_Disposition (To_Hostkit_Signal (Item), Host_Value) then
         Value := Unknown_Disposition;
         return False;
      end if;

      Value := From_Hostkit_Disposition (Host_Value);
      return True;
   end Current_Disposition;

   function Set_Disposition (Item : Signal; Value : Disposition) return Boolean is
   begin
      return Value /= Unknown_Disposition
        and then Hostkit.Signals.Set_Disposition (To_Hostkit_Signal (Item), To_Hostkit_Disposition (Value));
   end Set_Disposition;
end Posix_Tools.Host_Adapters.Signals;
