# ═══════════════════════════════════════════════════════════════════════
# EXTREME Complexity Prompts — Level 2
# ═══════════════════════════════════════════════════════════════════════
# These target the obscure corners of MQL5 where LLMs genuinely fail:
# template specialization, operator overloading, #import conflicts,
# event model edge cases, and MetaEditor-specific compilation quirks.
# ═══════════════════════════════════════════════════════════════════════

# ── PROMPT 6: Template Classes + Operator Overloading ────────────────
# MQL5 templates differ subtly from C++ — LLMs almost always get
# the syntax wrong for operator overloading inside template classes.
PROMPT_6 = """
Create an Expert Advisor with the following EXACT specifications:
- Define a template class CMatrix<T> with operator overloading:
  * operator+ for matrix addition
  * operator* for matrix-scalar multiplication
  * operator[] for row access returning a pointer to T array
  * operator= for deep copy assignment
  * A method Transpose() that returns a new CMatrix<T>
  * A method Determinant() for 2x2 and 3x3 matrices using template specialization
- Define a template class CTimeSeries<T> that inherits from CMatrix<T>
  and adds methods: SMA(int period), EMA(int period), Correlation(CTimeSeries<T>& other)
- Use CTimeSeries<double> to store OHLCV data for 3 symbols simultaneously
- Implement a Kalman filter using CMatrix<double> for price prediction:
  * State transition matrix F (2x2)
  * Observation matrix H (1x2) 
  * Process noise covariance Q
  * Measurement noise covariance R
  * Prediction step and update step as separate methods
- Trade based on Kalman filter predicted price vs current price
- Use MQL5's native matrix type alongside your custom CMatrix<T> and
  convert between them using a helper method ToNativeMatrix()
- Implement OnTester() returning Sharpe ratio calculated from equity curve
- Use FrameAdd() in OnTesterPass() to collect optimization results
"""

# ── PROMPT 7: Multiple #import + Interface + Event Chaining ──────────
# The #import directive in MQL5 has strict rules about function
# declarations that LLMs consistently violate.
PROMPT_7 = """
Create an Expert Advisor with these EXACT features:
- Use #import "user32.dll" to declare: 
  int MessageBoxW(int hWnd, string text, string caption, int type);
  int GetAsyncKeyState(int vKey);
- Use #import "kernel32.dll" to declare:
  int GetTickCount();
  void Sleep(int milliseconds);
- End each #import block properly
- Define an interface IStrategy with pure virtual methods:
  virtual bool CheckEntry(void) = 0;
  virtual bool CheckExit(void) = 0;
  virtual double GetStopLoss(void) = 0;
  virtual double GetTakeProfit(void) = 0;
  virtual string GetName(void) = 0;
- Implement 3 classes that inherit from IStrategy:
  CMeanReversionStrategy, CTrendFollowingStrategy, CBreakoutStrategy
- Each strategy uses different indicators (Bollinger Bands, ADX+MA, Donchian Channel)
- Create a CStrategyRotator class that:
  * Holds IStrategy* pointers in a CArrayObj
  * Evaluates all strategies every bar
  * Selects the strategy with the highest recent win rate
  * Switches active strategy and logs the rotation event
- Implement OnChartEvent() to:
  * Create 3 buttons on the chart (one per strategy) using ObjectCreate()
  * Handle CHARTEVENT_OBJECT_CLICK to force-select a strategy
  * Update button colors to show which strategy is active
- Use CSymbolInfo, CPositionInfo, COrderInfo, CDealInfo, CHistoryOrderInfo
  all from the standard MQL5 Trade library simultaneously
- Track strategy performance using CHashMap<string, double> for win rates
"""

# ── PROMPT 8: Resource Framework + Database + Encryption ─────────────
# Combining resource management, SQLite-like storage via files,
# and bitwise encryption will almost certainly produce errors.
PROMPT_8 = """
Create an Expert Advisor that implements:
- A custom encrypted configuration system:
  * Use ResourceCreate() to embed a default config as a resource
  * Read with ResourceReadImage() and decode from pixel ARGB values
  * Implement XOR encryption/decryption using a 256-byte key array
  * Store encrypted config using FileSave() with FILE_COMMON flag
  * Load and decrypt on startup using FileLoad()
- A trade journal database using flat files:
  * Custom struct STradeRecord with 15 fields (ticket, symbol, type,
    lots, openPrice, closePrice, openTime, closeTime, profit, swap,
    commission, magicNumber, comment, maxDrawdown, maxFavorable)
  * Binary serialization using FileWriteStruct() and FileReadStruct()
  * Index file using FileSeek() for O(log n) binary search by ticket
  * Method to export to CSV with proper datetime formatting
- A position monitor using OnTradeTransaction():
  * Detect TRADE_TRANSACTION_DEAL_ADD events
  * Check deal entry type with HistoryDealGetInteger(DEAL_ENTRY)
  * Distinguish between DEAL_ENTRY_IN, DEAL_ENTRY_OUT, DEAL_ENTRY_INOUT
  * Update journal for each transaction
- A custom indicator buffer drawn on the chart:
  * Use IndicatorSetString(INDICATOR_SHORTNAME) 
  * SetIndexBuffer() with INDICATOR_DATA mode
  * PlotIndexSetInteger() for line style and color
  * Update from within the EA using iCustom() on itself
- Implement EventSetMillisecondTimer(100) for high-frequency monitoring
- Use MathSrand(GetTickCount()) and MathRand() for Monte Carlo position sizing
- Send HTML-formatted email reports using SendMail() with trade statistics
"""

# ── PROMPT 9: Multi-EA Communication + Shared Memory ─────────────────
# GlobalVariable operations with proper locking, combined with
# complex order management, are a nightmare for LLMs.
PROMPT_9 = """
Create an Expert Advisor designed for multi-instance coordination:
- Use GlobalVariableTemp() to create session-scoped shared variables
- Implement a mutex using GlobalVariableSetOnCondition() for thread safety:
  * CreateMutex(string name) — tries to acquire lock with timeout
  * ReleaseMutex(string name) — releases the lock
  * Wraps critical sections for shared resource access
- Shared state via GlobalVariables:
  * Total exposure across all EA instances (sum of all lot sizes)
  * Maximum allowed total exposure (configurable)
  * Signal broadcast: one EA can signal others to close all positions
- Implement a custom COrderManager class using CTrade that:
  * Opens OCO (One-Cancels-Other) order pairs using pending orders
  * Uses ORDER_TIME_SPECIFIED for time-limited pending orders
  * Implements partial close using CTrade::PositionClosePartial()
  * Tracks slippage using (actualFillPrice - requestedPrice)
  * Handles ORDER_FILLING_RETURN execution mode for partial fills
  * Re-quotes handling with configurable max deviation
- Market microstructure analysis:
  * Use MarketBookAdd() and OnBookEvent() for Level 2 data
  * Parse MqlBookInfo array to calculate bid-ask imbalance
  * Detect large orders (icebergs) by tracking book changes
  * Store tick-by-tick data using MqlTick arrays with microsecond timestamps
- Implement OnTesterDeinit() for optimization cleanup
- Use TERMINAL_MEMORY_USED to monitor memory consumption
- Comment each position with a JSON-encoded metadata string parsed with StringFind()
"""

# ── PROMPT 10: Multi-Asset Portfolio + Risk Parity + Optimization ─────
# Combining portfolio theory math with MQL5's optimization framework
# and matrix operations will create subtle type-mismatch errors.
PROMPT_10 = """
Create a portfolio management Expert Advisor that:
- Manages a portfolio of exactly 8 forex pairs defined in an input string
  parameter parsed using StringSplit() into a string array
- Implements Risk Parity allocation:
  * Calculate 20-day rolling volatility for each pair using custom StdDev
  * Inverse volatility weighting: weight_i = (1/vol_i) / sum(1/vol_j)
  * Rebalance weights weekly using a day-of-week check via 
    TimeDayOfWeek(TimeTradeServer())
  * Store weight history in a 2D array double weights[8][52]
- Covariance matrix calculation:
  * Use MQL5 native matrix type: matrix covMatrix
  * Populate using CopyClose() returns for each symbol
  * Calculate portfolio variance as w' * Cov * w using matrix operations
  * Annualize using sqrt(252) factor
- Maximum drawdown tracking:
  * Custom CEquityCurve class tracking peak equity and current equity
  * Calculate Calmar ratio (annual return / max drawdown)
  * If drawdown exceeds input threshold, reduce all positions by 50%
- Order execution:
  * For each symbol, calculate target lots from weight * total_risk_budget
  * Compare target vs current position using PositionGetDouble(POSITION_VOLUME)
  * If difference > minimum lot, execute the delta trade
  * Handle symbols with different lot step sizes using SymbolInfoDouble(SYMBOL_VOLUME_STEP)
  * Round lot sizes properly using MathFloor(lots / lotStep) * lotStep
- Generate weekly performance report as chart comment using StringFormat()
  with a formatted table showing: symbol, weight, P&L, Sharpe contribution
- Use ENUM_TIMEFRAMES array to support multi-timeframe volatility lookback
- Store optimization results in a custom frame using FrameAdd() with 
  double array containing: totalReturn, maxDD, sharpeRatio, calmarRatio
"""
