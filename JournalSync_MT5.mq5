//+------------------------------------------------------------------+
//|                                              JournalSync_MT5.mq5 |
//+------------------------------------------------------------------+
#property copyright "Trading Journal Pro"
#property version   "1.00"
#property script_show_inputs

input string InpSupabaseUrl = "URL_FROM_WEBSITE"; 
input string InpApiKey      = "API_KEY_FROM_WEBSITE";
input string InpUserID      = "USER_ID_FROM_WEBSITE";
input int    InpDays        = 30;

void OnStart()
{
   string url = InpSupabaseUrl + "/rest/v1/rpc/upload_trade";
   string headers = "Content-Type: application/json\r\n" + 
                    "apikey: " + InpApiKey + "\r\n" + 
                    "Authorization: Bearer " + InpApiKey;

   if(!HistorySelect(TimeCurrent() - (InpDays * 86400), TimeCurrent())) return;
   
   int total = HistoryDealsTotal();
   int synced = 0;
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      
      // Nur Ausgänge (Entry Out) von Kaufen/Verkaufen
      if(entry == DEAL_ENTRY_OUT && (type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL))
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         double closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
         double openPrice = 0.0; // Schwer in HistoryDeals zu finden ohne Positions-Match, setzen wir auf 0 oder close
         
         string dir = (type == DEAL_TYPE_SELL) ? "LONG" : "SHORT"; // Wenn wir Verkaufen um zu schließen, waren wir Long
         string res = (profit >= 0) ? "WIN" : "LOSS";

         // JSON Bauen
         string json = "{";
         json += "\"p_user_id\":\"" + InpUserID + "\","; 
         json += "\"p_date\":\"" + TimeToString(time, TIME_DATE) + "\",";
         json += "\"p_time\":\"" + TimeToString(time, TIME_MINUTES) + "\",";
         json += "\"p_instrument\":\"" + symbol + "\",";
         json += "\"p_strategy\":\"AutoSync\",";
         json += "\"p_direction\":\"" + dir + "\",";
         json += "\"p_entry\":0.0,"; 
         json += "\"p_exit\":" + DoubleToString(closePrice, 5) + ",";
         json += "\"p_pl\":" + DoubleToString(profit, 2) + ",";
         json += "\"p_result\":\"" + res + "\",";
         json += "\"p_notes\":\"Ticket: " + IntegerToString(ticket) + "\"";
         json += "}";
         
         StringReplace(json, ".", "-");

         char postData[];
         StringToCharArray(json, postData, 0, StringLen(json));
         char resultData[];
         string resultHeaders;
         
         int response = WebRequest("POST", url, headers, 3000, postData, resultData, resultHeaders);
         if(response == 200 || response == 204) synced++;
      }
   }
   Alert("Sync finished! " + IntegerToString(synced) + " trades sent.");
}