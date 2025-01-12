#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//パラメーター設定
input int Slippage = 4;             //Slippage(pips)
input int MagicNumber = 12345;      //Magic Number
input int N = 200;                  //Max Position
input double LotCurrency = 100000;  //Currency Unit Per lot
input double LowerLimitLine = 50;   //Lower Limit Line
input double TakeProfit = 1000;     //Take Profit
input string EntryComment = "joji"; //Comment

double Lots;                        //Entry Lot
double valuePerPips;                //Value Per Pips
double spread;
int NanpinPips[]={};             //Avaraging Down Width

int OnInit()
    {
        valuePerPips = Point * 10;
        if(N <= 1){
            Print("Max Position should be set to 2 or more");
            return(INIT_FAILED);
        }
        if(StringSubstr(Symbol(), 3, 3) != "JPY"){
            Print("Please select JPY currency pair");
            return(INIT_FAILED);
        }
        ArrayResize(NanpinPips, N);

        return(INIT_SUCCEEDED);
    }

void OnDeinit(const int reason)
    {

    }

void OnTick()
    {
        spread = (Ask - Bid) / valuePerPips;

        //保有ポジションの計算部分
        int buyCount = 0;             //保有中の買いポジション数
        double firstBuyProfitPips = 0;//初回ポジションの損益(pips)
        double sumBuyProfit = 0;      //保有ポジションの合計

        for(int i = 0; i < OrdersTotal(); i++){
            if(OrderSelect(i, SELECT_BY_POS) == true && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()){
                if(OrderType() == OP_BUY){
                    buyCount++;
                    if(firstBuyProfitPips == 0)firstBuyProfitPips = (Bid - OrderOpenPrice()) / valuePerPips;
                    sumBuyProfit = sumBuyProfit + OrderProfit() + OrderSwap() + OrderCommission();
                }
            }
        }

        //ポジション保有時にバックテストが終わると損害が発生するのを防止する
        if(StringToTime("2023.01.01 00:00") <= TimeCurrent() && buyCount == 0 && IsTesting())return;

        //初回エントリー
        if(buyCount == 0){
            int NanpinWidth = (int)MathCeil((Close[0] - LowerLimitLine) / double(N) / valuePerPips);
            for(int i = 0; i < N; i++){
                NanpinPips[i] = NanpinWidth * (i + 1) * -1;
            }
            Lots = getCalcLot(NanpinWidth);
            if(Lots == 0){
                Print("Lot is now 0. Please increase margin or decrease Max Position(N)");
                ExpertRemove();
            }
            int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage * 10, 0, 0, EntryComment, MagicNumber, 0, clrRed);
            if(ticket < 0)Print("Error OrderSend" + (string)GetLastError());
        }

        //ナンピンエントリー
        if(buyCount >= 1 && buyCount < N){
            //ナンピンの条件を満たしているかどうか
            if(NanpinPips[buyCount - 1] > firstBuyProfitPips){
                int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage * 10, 0, 0, EntryComment, MagicNumber, 0, clrRed);
                if(ticket < 0)Print("Error OrderSend" + (string)GetLastError());
            }
        }

        //決済
        if(TakeProfit < sumBuyProfit){
            AllClose();
            }
    }
    //保有中のポジションを全て決済する関数
    void AllClose(){
        int errorCheck = 0;
        while(!IsStopped()){
            for(int i = OrdersTotal() - 1; i >= 0; i--){
                if(OrderSelect(i, SELECT_BY_POS) == true && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()){
                    if(!OrderClose(OrderTicket(), OrderLots(), Bid, Slippage * 10, clrGreen)){
                        errorCheck = 1;
                    }
                }
            }
            if(errorCheck == 0)break;
            Sleep(500);
            RefreshRates();
        }
    }

    //Nポジション保有しても破綻しないロット数を計算して返す関数
    double getCalcLot(int NanpinWidth){
        double minLot = MarketInfo(Symbol(), MODE_MINLOT);
        double iLot = minLot;
        while(true){
            double sumLosePips = 0;        //Nポジション保有した時の損害pips(有効証拠金計算用)
            double RequiredMargin = 0;     //必要証拠金

            //Nポジションを保有した時の有効証拠金と必要証拠金を計算する
            for(int iPosition = 0; iPosition < N; iPosition++){
                sumLosePips = sumLosePips + (iPosition * NanpinWidth);
                RequiredMargin = RequiredMargin + ((Close[0] - (NanpinWidth * iPosition * valuePerPips)) * iLot * LotCurrency / AccountLeverage());//購入時の為替レート×購入通貨数÷最大レバレッジ
            }
            double EffectiveMargin = AccountInfoDouble(ACCOUNT_BALANCE) - (sumLosePips * LotCurrency * iLot * valuePerPips);//証拠金と副損益を合計
            if(EffectiveMargin / RequiredMargin * 100 < AccountStopoutLevel())break;
            iLot = iLot + minLot;
        }
        return iLot - minLot;
    }
