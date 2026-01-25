//+------------------------------------------------------------------+
//|                                              JournalSync_MT4.mq4 |
//|                                      Auto-Sync via Supabase RPC  |
//+------------------------------------------------------------------+
#property copyright "Trading Journal Pro"
#property strict
#property show_inputs

// --- USER INPUTS (Kunde kopiert diese Daten aus dem Web) ---
input string InpSupabaseUrl = "URL_FROM_WEBSITE"; 
input string InpApiKey      = "API_KEY_FROM_WEBSITE";
input string InpUserID      = "USER_ID_FROM_WEBSITE";
input int    InpDays        = 30; // Wie viele Tage zurück?

void OnStart()
{
   if(!IsDllsAllowed()) { 
      Alert("Please enable 'Allow WebRequest' in Tools->Options->Expert Advisors!"); 
      return; 
   }

   // Wir nutzen den RPC Endpoint (Database Function)
   string url = InpSupabaseUrl + "/rest/v1/rpc/upload_trade";
   
   string headers = "Content-Type: application/json\r\n" + 
                    "apikey: " + InpApiKey + "\r\n" + 
                    "Authorization: Bearer " + InpApiKey;

   int total = OrdersHistoryTotal();
   datetime cutoff = TimeCurrent() - (InpDays * 24 * 60 * 60);
   int synced = 0;

   for(int i = 0; i < total; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         // Nur geschlossene Trades, keine Pending Orders
         if(OrderType() <= 1 && OrderCloseTime() > cutoff) 
         {
            // JSON manuell bauen (MQL4 hat keinen Parser)
            string dir = (OrderType() == OP_BUY) ? "LONG" : "SHORT";
            string res = (OrderProfit() >= 0) ? "WIN" : "LOSS";
            double pl = OrderProfit() + OrderSwap() + OrderCommission();
            
            // Format muss exakt den Parametern der SQL Funktion entsprechen (p_...)
            string json = "{";
            json += "\"p_user_id\":\"" + InpUserID + "\","; 
            json += "\"p_date\":\"" + TimeToString(OrderCloseTime(), TIME_DATE) + "\","; // yyyy.mm.dd
            json += "\"p_time\":\"" + TimeToString(OrderCloseTime(), TIME_MINUTES) + "\",";
            json += "\"p_instrument\":\"" + OrderSymbol() + "\",";
            json += "\"p_strategy\":\"AutoSync\",";
            json += "\"p_direction\":\"" + dir + "\",";
            json += "\"p_entry\":" + DoubleToString(OrderOpenPrice(), Digits) + ",";
            json += "\"p_exit\":" + DoubleToString(OrderClosePrice(), Digits) + ",";
            json += "\"p_pl\":" + DoubleToString(pl, 2) + ",";
            json += "\"p_result\":\"" + res + "\",";
            json += "\"p_notes\":\"Ticket: " + IntegerToString(OrderTicket()) + "\"";
            json += "}";

            // Fix Date Format (Punkte zu Bindestrichen)
            StringReplace(json, ".", "-");

            char postData[];
            StringToCharArray(json, postData, 0, StringLen(json));
            char resultData[];
            string resultHeaders;
            
            // Senden
            int response = WebRequest("POST", url, headers, 3000, postData, resultData, resultHeaders);
            
            if(response == 200 || response == 204) synced++;
            else Print("Error Syncing Ticket " + IntegerToString(OrderTicket()) + ": " + IntegerToString(response));
         }
      }
   }
   
   Alert("Sync finished! " + IntegerToString(synced) + " trades sent to journal.");
}