# ═══════════════════════════════════════════════════════════════════════
# Complex Strategy Prompts for Testing the Error Correction Loop
# ═══════════════════════════════════════════════════════════════════════
# These prompts are designed to push GPT into generating MQL5 code that
# uses advanced features where LLMs commonly make syntax errors.
# Copy-paste any of these into the frontend to test compilation.
# ═══════════════════════════════════════════════════════════════════════

# ── PROMPT 1: Multi-Timeframe + Custom Indicator + OOP ──────────────
# LLMs often mess up iCustom() calls, class inheritance, and
# multi-timeframe handle management in MQL5.
PROMPT_1 = """
Create an Expert Advisor that uses a custom class hierarchy:
- A base class CSignalBase with virtual methods CheckBuy() and CheckSell()
- A derived class CIchimokuSignal that checks Ichimoku Cloud on H4 timeframe
  (Tenkan > Kijun, price above Kumo cloud, and Chikou Span confirms)
- A derived class CBollingerRSISignal that checks when price touches
  the lower Bollinger Band (20,2) AND RSI(14) is below 30 on M15 timeframe
- A CSignalManager class that holds an array of CSignalBase pointers,
  iterates through them, and only opens a trade when ALL signals agree
- Use proper MQL5 indicator handles created in OnInit() with
  iIchimoku(), iBollinger(), iRSI() — store handles as class members
- Implement proper handle releasing in OnDeinit()
- Use CTrade class for order execution with 1.5% risk per trade
- Calculate lot size dynamically based on account balance and stop loss distance
- Add a trailing stop that uses ATR(14) multiplied by 2.0
- Store trade history in a custom struct array for logging
"""

# ── PROMPT 2: Multi-Currency Correlation + Matrix Math ──────────────
# LLMs struggle with MQL5's matrix operations, multi-symbol data
# access, and the OnTimer() event with proper synchronization.
PROMPT_2 = """
Build a multi-currency correlation Expert Advisor that:
- Monitors 6 pairs simultaneously: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, NZDUSD
- Uses OnTimer() event set to 60 seconds for recalculation
- Calculates a 50-period rolling Pearson correlation matrix between all pairs
  using MQL5's native matrix and vector types (matrix, vector)
- Copies close prices for each symbol using CopyClose() into separate arrays
- Detects correlation breakdowns: when a normally correlated pair (r > 0.8)
  suddenly drops below 0.5, it opens a mean-reversion trade
- Implements a custom CCorrelationMatrix class with methods:
  Calculate(), GetCorrelation(int i, int j), PrintMatrix()
- Uses CHashMap to track which pair combinations are currently being traded
- Implements proper symbol synchronization checks with SymbolInfoInteger()
- Position sizing based on Kelly Criterion calculation
- Maximum 3 open positions at any time across all symbols
- Uses MQL5 resource framework to store correlation snapshots
"""

# ── PROMPT 3: Neural Network Pattern + File I/O + Events ────────────
# LLMs get confused with MQL5 file operations, OnChartEvent(),
# custom enumerations, and complex pattern recognition logic.
PROMPT_3 = """
Create an Expert Advisor with these advanced features:
- Define a custom enumeration ENUM_PATTERN_TYPE with at least 8 candlestick
  patterns: HAMMER, ENGULFING_BULL, ENGULFING_BEAR, DOJI, MORNING_STAR,
  EVENING_STAR, THREE_WHITE_SOLDIERS, THREE_BLACK_CROWS
- Create a CPatternDetector class that scans the last 5 candles and returns
  an array of detected ENUM_PATTERN_TYPE values using CArrayInt
- Implement a scoring system: each pattern has a weight (input parameter),
  the EA only trades when the combined score exceeds a threshold
- Log every detected pattern to a CSV file using FileOpen(), FileWrite(),
  FileClose() with proper error handling
- Read configuration from an INI file on startup using FileReadString()
- Implement OnChartEvent() to allow users to click on the chart to place
  horizontal lines that act as support/resistance levels
- The EA should check if price is near any user-drawn line before trading
- Use the CCanvas class to draw a real-time dashboard panel on the chart
  showing: current patterns detected, score, account stats, open positions
- Implement MQL5's OnTradeTransaction() to track order fills and modifications
- Use #import to call a DLL function for advanced math (declare but use
  a fallback pure-MQL5 implementation if DLL is not available)
"""

# ── PROMPT 4: Grid Trading + State Machine + Database ────────────────
# This pushes the LLM into complex state management, dynamic arrays,
# and MQL5's object-oriented trading classes.
PROMPT_4 = """
Build a grid trading Expert Advisor with a finite state machine:
- Define states: IDLE, BUILDING_GRID, GRID_ACTIVE, RECOVERY, SHUTDOWN
- Use a CObject-derived CGridLevel class with properties: price, lotSize,
  orderTicket, isActive, levelIndex, direction (BUY/SELL)
- Create a CList of CGridLevel objects for dynamic grid management
- Grid parameters: startPrice, gridSpacing (in points), numberOfLevels (up to 20),
  lotMultiplier for martingale progression
- When price moves through a grid level, open a pending order at the next level
- Implement a drawdown-based recovery mode: if floating loss exceeds 5% of
  balance, switch to RECOVERY state which closes profitable positions first
- Use GlobalVariableSet/Get to persist grid state across EA restarts
- Implement CSymbolInfo for proper tick size and point calculations
- Use ORDER_FILLING_FOK or ORDER_FILLING_IOC based on symbol execution mode
  detected via SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE)
- Send push notifications via SendNotification() on state changes
- Implement a custom CMoneyManagement class that adjusts grid spacing
  based on ATR(20) volatility
- Track total grid P&L using HistoryDealGetDouble() on closed positions
"""

# ── PROMPT 5: Machine Learning Features + WebRequest ─────────────────
# WebRequest, complex struct arrays, and feature engineering are
# areas where MQL5 syntax diverges heavily from what LLMs expect.
PROMPT_5 = """
Create an Expert Advisor that:
- Calculates 15 technical features per bar: RSI(14), RSI(7), MACD signal,
  MACD histogram, Stochastic %K, %D, ADX, +DI, -DI, CCI(20), Williams %R,
  MFI(14), OBV rate of change, Bollinger %B, and ATR(14) normalized
- Stores features in a custom struct SFeatureVector with all 15 doubles
- Maintains a circular buffer (ring buffer) of the last 200 SFeatureVector
  using a template class CRingBuffer<T>
- Normalizes all features to 0-1 range using min-max scaling calculated
  from the buffer history
- Uses WebRequest() to POST the feature vector as JSON to an external
  REST API endpoint (configurable URL input parameter)
- Parses the JSON response using string manipulation to extract a
  prediction value (0 = sell, 1 = buy, 0.5 = neutral)
- Implements exponential moving average of predictions over last 10 bars
- Only trades when smoothed prediction is above 0.7 (buy) or below 0.3 (sell)
- Proper error handling for WebRequest timeouts and HTTP error codes
- Use MQL5's IndicatorCreate() with ENUM_INDICATOR types instead of
  individual iRSI(), iMACD() calls
- Implement OnTester() and OnTesterInit() for optimization support
"""
