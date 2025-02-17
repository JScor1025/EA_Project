#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


//EA基本設定
input double Lots = 0.1;          //Lots
input int Slippage = 4;           //Slippage(pips)
input int MaxSpread = 5;          //Max Spread(pips)
input int MagicNumber = 54637874; //Magic Number
input string EntryComment = "";   //Comment
input int TakeProfit = 0;        //Take Profit(pips)
input int LossCut = 0;           //Loss Cut(pips)

//ポジション制御
input bool AllowRyoudate = false; //CrossTrading(ON/OFF)
input int MaxBuyPositions = 5;    //Max Buy Position
input int MaxSellPositions = 5;   //Max Sell Position

//エントリー決済時
input int RSIPeriod = 7;          //RSI Period
input int BBPeriod = 80;          //BB Period
input double BBDevi = 1.0;        //BB Devi
input int EnvPeriod = 120;        //Env Period
input double EnvDevi = 0.01;      //Env Devi
input int MAPeriod = 200;         //MA Period
input int EntryUpLine = 80;       //Entry UpLine
input int EntryDownLine = 20;     //Entry DownLine
input int CloseUpLine = 65;       //Close UpLine
input int CloseDownLine = 35;     //Close DownLine

//時間制限設定
input string TimeStart1 = "21:00";//Entry Start 1
input string TimeEnd1 = "23:59";  //Entry End 1
input string TimeStart2 = "00:00";//Entry Start 2
input string TimeEnd2 = "02:00";  //Entry End 2


double valuePerPips;              //Value Per Pips
double spread;                    //Current Spread

int OnInit()
   {
   valuePerPips = Point * 10;
   HideTestIndicators(true);
   return(INIT_SUCCEEDED);
   }

void OnTick()
   {
      spread = (Ask - Bid) / valuePerPips;
      int buyCount = 0;
      int sellCount = 0;

      //保有ポジション計算部分
      if(OrdersTotal() > 0){
         for(int i = 0; i < OrdersTotal(); i++){
            if(OrderSelect(i, SELECT_BY_POS) == true && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()){
               if(OrderType() == OP_BUY){
                  buyCount++;
               }
               if(OrderType() == OP_SELL){
                  sellCount++;
               }
            }
         }
      }
      //エントリー
      if(buyCount < MaxBuyPositions && (AllowRyoudate || sellCount == 0)){
         if(checkBuy()){
            int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage * 10, LossCut == 0 ? 0 : Ask - LossCut * valuePerPips,TakeProfit == 0 ? 0 : Ask + TakeProfit * valuePerPips, EntryComment, MagicNumber, 0, clrRed);
            if( ticket < 0)Print("Error OrderSend:" + (string)GetLastError());
            else buyCount++;
         }
      }
      if(sellCount < MaxSellPositions && (AllowRyoudate || buyCount == 0)){
         if(checkSell()){
            int ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage * 10, LossCut == 0 ? 0 : Bid + LossCut * valuePerPips,TakeProfit == 0 ? 0 : Bid - TakeProfit * valuePerPips, EntryComment, MagicNumber, 0, clrBlue);
            if( ticket < 0)Print("Error OrderSend:" + (string)GetLastError());
            else sellCount++;
         }
      }
      //決済
      if(checkBuyClose()){
         BuyAllClose();
      }
      if(checkSellClose()){
         SellAllClose();
      }
   }

   bool checkBuy(){
      double RSI = iRSI(Symbol(), Period(), RSIPeriod, 0, 1);
      double BBDown = iBands(Symbol(), Period(), BBPeriod, BBDevi, 0, 0, 2, 1);
      double MA1 = iMA(Symbol(), Period(), MAPeriod, 0, 1, 0, 1);
      double MA2 = iMA(Symbol(), Period(), MAPeriod, 0, 1, 0, 2);
      if(spread >= MaxSpread)return false;
      if(!(TimeIfCheck(TimeStart1,TimeEnd1)) && TimeIfCheck(TimeStart2,TimeEnd2))return false;
      if(RSI > EntryDownLine) return false;
      if(BBDown < Close[1])return false;
      if(MA1 < MA2)return false;

      return true;
   }

   bool checkSell(){
      double RSI = iRSI(Symbol(), Period(), RSIPeriod, 0, 1);
      double BBUp = iBands(Symbol(), Period(), BBPeriod, BBDevi, 0, 0, 1, 1);
      double MA1 = iMA(Symbol(), Period(), MAPeriod, 0, 1, 0, 1);
      double MA2 = iMA(Symbol(), Period(), MAPeriod, 0, 1, 0, 2);
      if(spread >= MaxSpread)return false;
      if(!(TimeIfCheck(TimeStart1,TimeEnd1)) && TimeIfCheck(TimeStart2,TimeEnd2))return false;
      if(RSI < EntryUpLine) return false;
      if(BBUp > Close[1])return false;
      if(MA1 > MA2)return false;
      return true;
   }
   bool checkBuyClose(){
      double RSI = iRSI(Symbol(), Period(), RSIPeriod, 0, 1);
      double EnvDown = iEnvelopes(Symbol(), Period(), EnvPeriod, 0, 0, 0, EnvDevi, 1, 1);

      if (RSI < CloseDownLine)return false;
      if(High[1] < EnvDown)return false;
      return true;
   }
   bool checkSellClose(){
      double RSI = iRSI(Symbol(), Period(), RSIPeriod, 0, 1);
      double EnvUp = iEnvelopes(Symbol(), Period(), EnvPeriod, 0, 0, 0, EnvDevi, 2, 1);

      if (RSI > CloseUpLine)return false;
      if(Low[1] > EnvUp)return false;
      return true;
   }
   void BuyAllClose(){
      int errorCheck = 0;
      while(!IsStopped()){
         for(int i = OrdersTotal() - 1 ; i >= 0; i--){
            if(OrderSelect(i, SELECT_BY_POS) == true && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()){
               if(OrderType() == OP_BUY){
                  if(!OrderClose(OrderTicket(), OrderLots(), Bid, Slippage * 10, clrGreen)){
                     errorCheck = 1;
                  }
               }
            }
         }
         if(errorCheck == 0)break;
         Sleep(500);
         RefreshRates();
      }
   }
   void SellAllClose(){
      int errorCheck = 0;
      while(!IsStopped()){
         for(int i = OrdersTotal() - 1 ; i >= 0; i--){
            if(OrderSelect(i, SELECT_BY_POS) == true && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()){
               if(OrderType() == OP_SELL){
                  if(!OrderClose(OrderTicket(), OrderLots(), Ask, Slippage * 10, clrGreen)){
                     errorCheck = 1;
                  }
               }
            }
         }
         if(errorCheck == 0)break;
         Sleep(500);
         RefreshRates();
      }
   }

bool TimeIfCheck( string timeif_start,string timeif_end ){
   int iIndex;
   int iTime_ts = 0;
   int iTime_ms = 0;
   int iTime_te = 0;
   int iTime_me = 0;

   iIndex = StringFind(timeif_start,":",0);
   iTime_ts = StrToInteger(StringSubstr(timeif_start,0,iIndex));
   if(iIndex > 0) iTime_ms = StrToInteger(StringSubstr(timeif_start,iIndex+1,2));
   iIndex = StringFind(timeif_end,":",0);
   iTime_te = StrToInteger(StringSubstr(timeif_end,0,iIndex));
   if(iIndex > 0) iTime_me = StrToInteger(StringSubstr(timeif_end,iIndex+1,2));

   if( iTime_ts < iTime_te || (iTime_ts == iTime_te && iTime_ms <= iTime_me) ){
      if( Hour() > iTime_ts || (Hour() == iTime_ts && Minute() >= iTime_ms) ){
         if( Hour() < iTime_te || (Hour() == iTime_te && Minute() <= iTime_me) ){
            return(true);
         }
      }
   }else{
      if( (Hour() > iTime_ts || (Hour() == iTime_ts && Minute() >= iTime_ms)) || (Hour() < iTime_te || (Hour() == iTime_te && Minute() <= iTime_me)) ){
         return(true);
      }
   }

   return(false);
}
