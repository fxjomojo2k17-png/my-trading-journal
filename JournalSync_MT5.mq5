//+------------------------------------------------------------------+
//|                                         JournalSync_Clean.mq5    |
//+------------------------------------------------------------------+
#property copyright "Trading Journal Pro"
#property version   "1.25"
#property script_show_inputs

input string InpSupabaseUrl = "https://nrmivhzvwqpnwedvkbbz.supabase.co"; 
input string InpApiKey      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ybWl2aHp2d3FwbndlZHZrYmJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3MjgzMTIsImV4cCI6MjA4NDMwNDMxMn0.DmpCTBurgMHoba3KpsjRCEOqltV4-bL06ezPr7gAbyg";
input string InpUserID      = "5a694710-07cf-49d6-91b9-94bd638f8ad8";
input int    InpDays        = 365;

// Hilfsfunktion zum Entfernen von unnötigen Nullen
string CleanDouble(double value) {
   string s = DoubleToString(value, 8); 
   int len = StringLen(s);
   for(int i = len - 1; i >= 0; i--) {
      ushort c = StringGetCharacter(s, i);
      if(c != '0' && c != '.') break;
      if(c == '.') { len = i; break; }
      len = i;
   }
   return StringSubstr(s, 0, len);
}

void OnStart()
{
   string targetUrl = InpSupabaseUrl + "/rest/v1/rpc/upload_trade";
   string headers = "Content-Type: application/json\r\n" + "apikey: " + InpApiKey + "\r\n" + "Authorization: Bearer " + InpApiKey + "\r\n";

   if(!HistorySelect(TimeCurrent() - (InpDays * 86400), TimeCurrent())) return;
   
   int totalDeals = HistoryDealsTotal();
   ulong tickets[];
   ArrayResize(tickets, totalDeals);
   
   int outCount = 0;
   for(int i=0; i<totalDeals; i++) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         tickets[outCount] = t;
         outCount++;
      }
   }
   ArrayResize(tickets, outCount);

   int synced = 0;
   for(int i = 0; i < outCount; i++)
   {
      ulong ticket = tickets[i];
      if(!HistoryDealSelect(ticket)) continue;

      long posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      double exitPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      long type = HistoryDealGetInteger(ticket, DEAL_TYPE);

      double entryPrice = 0.0;
      if(HistorySelectByPosition(posID))
      {
         for(int d = 0; d < HistoryDealsTotal(); d++)
         {
            ulong tEntry = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(tEntry, DEAL_ENTRY) == DEAL_ENTRY_IN) {
               entryPrice = HistoryDealGetDouble(tEntry, DEAL_PRICE);
               break; 
            }
         }
      }
      if(entryPrice == 0) entryPrice = exitPrice;

      string dateStr = TimeToString(time, TIME_DATE);
      StringReplace(dateStr, ".", "-");

      // Hier nutzen wir jetzt CleanDouble für saubere Zahlen
      string json = "{"
         "\"p_user_id\":\"" + InpUserID + "\","
         "\"p_date\":\"" + dateStr + "\","
         "\"p_time\":\"" + TimeToString(time, TIME_MINUTES) + "\","
         "\"p_instrument\":\"" + symbol + "\","
         "\"p_strategy\":\"MT5-AutoSync\","
         "\"p_direction\":\"" + ((type==DEAL_TYPE_SELL)?"LONG":"SHORT") + "\","
         "\"p_entry\":" + CleanDouble(entryPrice) + ","
         "\"p_exit\":" + CleanDouble(exitPrice) + ","
         "\"p_pl\":" + DoubleToString(profit, 2) + ","
         "\"p_result\":\"" + ((profit>=0)?"WIN":"LOSS") + "\","
         "\"p_notes\":\"MT5 Import\","
         "\"p_mt5_id\":\"" + IntegerToString(ticket) + "\"" // Hier senden wir die ID separat
      "}";

      char postData[], resultData[];
      string resultHeaders;
      StringToCharArray(json, postData, 0, StringLen(json));
      WebRequest("POST", targetUrl, headers, 5000, postData, resultData, resultHeaders);
      synced++;
   }
   Alert("Fertig! ", synced, " Trades sauber übertragen.");
}
