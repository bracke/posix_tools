with Hostkit.Signals;

package body Posix_Tools.Host_Adapters.Signals is
   function To_Hostkit_Signal (Item : Signal) return Hostkit.Signals.Signal is
   begin
      case Item is
         when Interrupt =>
            return Hostkit.Signals.Signal_Interrupt;
         when Quit =>
            return Hostkit.Signals.Signal_Quit;
         when Terminate_Signal =>
            return Hostkit.Signals.Signal_Terminate;
         when Kill =>
            return Hostkit.Signals.Signal_Kill;
         when Hangup =>
            return Hostkit.Signals.Signal_Hangup;
         when Stop =>
            return Hostkit.Signals.Signal_Stop;
         when Terminal_Stop =>
            return Hostkit.Signals.Signal_Terminal_Stop;
         when Continue =>
            return Hostkit.Signals.Signal_Continue;
         when Pipe =>
            return Hostkit.Signals.Signal_Pipe;
         when Background_Read =>
            return Hostkit.Signals.Signal_Background_Read;
         when Background_Write =>
            return Hostkit.Signals.Signal_Background_Write;
         when Window_Change =>
            return Hostkit.Signals.Signal_Window_Change;
         when Child =>
            return Hostkit.Signals.Signal_Child;
      end case;
   end To_Hostkit_Signal;

   function From_Hostkit_Signal (Item : Hostkit.Signals.Signal) return Signal is
   begin
      case Item is
         when Hostkit.Signals.Signal_Interrupt =>
            return Interrupt;
         when Hostkit.Signals.Signal_Quit =>
            return Quit;
         when Hostkit.Signals.Signal_Terminate =>
            return Terminate_Signal;
         when Hostkit.Signals.Signal_Kill =>
            return Kill;
         when Hostkit.Signals.Signal_Hangup =>
            return Hangup;
         when Hostkit.Signals.Signal_Stop =>
            return Stop;
         when Hostkit.Signals.Signal_Terminal_Stop =>
            return Terminal_Stop;
         when Hostkit.Signals.Signal_Continue =>
            return Continue;
         when Hostkit.Signals.Signal_Pipe =>
            return Pipe;
         when Hostkit.Signals.Signal_Background_Read =>
            return Background_Read;
         when Hostkit.Signals.Signal_Background_Write =>
            return Background_Write;
         when Hostkit.Signals.Signal_Window_Change =>
            return Window_Change;
         when Hostkit.Signals.Signal_Child =>
            return Child;
      end case;
   end From_Hostkit_Signal;

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

   function Name (Item : Signal) return String is
   begin
      return Hostkit.Signals.Name (To_Hostkit_Signal (Item));
   end Name;

   function Number (Item : Signal) return Integer is
   begin
      return Hostkit.Signals.Number (To_Hostkit_Signal (Item));
   end Number;

   function From_Number (Value : Integer; Item : out Signal) return Boolean is
      Host_Item : Hostkit.Signals.Signal;
   begin
      if Hostkit.Signals.From_Number (Value, Host_Item) then
         Item := From_Hostkit_Signal (Host_Item);
         return True;
      end if;
      Item := Terminate_Signal;
      return False;
   end From_Number;

   function Send_To_Process (Process_Id : Integer; Item : Signal) return Boolean is
   begin
      return Hostkit.Signals.Send_To_Process (Process_Id, To_Hostkit_Signal (Item));
   end Send_To_Process;

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
