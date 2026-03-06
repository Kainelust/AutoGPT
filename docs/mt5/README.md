# XAUUSD M1 Scalping Bot (Vantage) – High Frequency

Neu von Grund auf: Diese Version ist auf **M1-Scalping mit möglichst vielen Trades** ausgelegt.

## Datei

- `XAUUSD_Vantage_SignalBot.mq5`

## Zielprofil

- Symbol: `XAUUSD`
- Timeframe: `M1`
- Fokus: hohe Trade-Frequenz, kurze Haltedauer, aktive Stop-Verwaltung

## Kernlogik

- Trend: EMA(5) vs EMA(13)
- Momentum: RSI(3) Midline-Cross (50)
  - Buy: RSI kreuzt über 50 + EMA5 > EMA13
  - Sell: RSI kreuzt unter 50 + EMA5 < EMA13
- Volatilitätsfilter: ATR(14) muss Mindestwert erreichen

## Für maximale Aktivität umgesetzt

- Hohe Tages-Trade-Grenze (`InpMaxTradesPerDay = 300`)
- Mehrere gleichzeitige Positionen erlaubt
  - `InpMaxOpenPositionsTotal = 4`
  - `InpMaxOpenPositionsPerSide = 2`
- Minimale Pause zwischen Entries (`InpMinSecondsBetweenEntries = 4`)
- Session standardmäßig 24h (`InpStartHour = 0`, `InpEndHour = 24`)

## Aktives Scalping-Trade-Management

- Enge ATR-Stops/Targets (SL 0.55x ATR, TP 0.85x ATR)
- Break-even
- ATR-Trailing-Stop
- Exit auf Gegensignal
- Zeitbasiertes Schließen nach maximaler Haltedauer



## Default jetzt auf "Live-Safe" gesetzt

- `InpScalpPreset = PRESET_CUSTOM`
- `InpLotMode = LOT_MODE_FIXED_LOT`
- `InpFixedLotSize = 0.01`
- `InpMaxOpenPositionsTotal = 4`
- `InpMaxOpenPositionsPerSide = 2`
- `InpMinSecondsBetweenEntries = 4`
- `InpMaxDailyLossPercent = 4.0`

Wichtig: Im `LOT_MODE_FIXED_LOT` wird **immer** `InpFixedLotSize` verwendet (nicht vom Preset überschrieben).

## Preset-Profile (neu)

- `InpScalpPreset = PRESET_CONSERVATIVE` → vorsichtiger, weniger Trades
- `InpScalpPreset = PRESET_BALANCED` → Standard
- `InpScalpPreset = PRESET_AGGRESSIVE` → maximale Aktivität
- `InpScalpPreset = PRESET_CUSTOM` → nutzt exakt deine eigenen Input-Werte

Tipp für deinen Wunsch „ja gerne":
- Für sehr viele Trades: `PRESET_AGGRESSIVE`
- Mit fixer Lot: `InpLotMode = LOT_MODE_FIXED_LOT` und z. B. `InpFixedLotSize = 0.01`

## Stabilitäts-Optimierungen (neue Runde)

Um den Bot robuster zu machen (statt nur aggressiver), wurden zusätzliche Filter eingebaut:

- **Trendstärke-Filter (ADX)**: Trades nur bei ausreichender Trendstärke (`InpUseAdxFilter`, `InpMinAdx`).
- **Volatilitäts-Regime-Filter**: Trades nur wenn ATR im Korridor liegt (`InpMinAtrPoints` bis `InpMaxAtrPoints`).
- **Loss-Streak-Cooldown**: Nach zu vielen Verlusttrades in Folge pausiert der Bot automatisch (`InpMaxConsecutiveLosses`, `InpLossPauseMinutes`).
- **Live-Safe Defaults** bleiben aktiv (Fixed Lot 0.01, begrenzte Parallelpositionen).

Wichtig: Kein Bot kann "immer" Profit garantieren. Diese Regeln sollen Overtrading und schlechte Marktphasen reduzieren.

## Lot-Size Einstellung (neu)

- `InpLotMode = LOT_MODE_FIXED_LOT` → handelt mit fixer Lot Size
- `InpFixedLotSize = 0.01` (oder z. B. 0.02, 0.10)
- Alternativ: `InpLotMode = LOT_MODE_RISK_PERCENT` und dann `InpRiskPercent` nutzen

## Schutzmechanismen (trotz High Frequency)

- Maximaler Spreadfilter (`InpMaxSpreadPoints`)
- Tagesverlust-Limit (`InpMaxDailyLossPercent`)
- Prozentuales Risiko pro Trade (`InpRiskPercent`) im Risk-Mode

## Vantage-Hinweis

- Falls dein Broker-Symbol Suffix hat (z. B. `XAUUSD.r`), `InpSymbol` anpassen.


## News-/No-Trade-Fenster (neu)

Damit der Bot nicht in kritischen Minuten (z. B. News/Rollover) einsteigt, gibt es jetzt 3 tägliche Sperrfenster (Serverzeit):

- `InpUseNoTradeWindows = true`
- Fenster 1: `InpNoTrade1StartHour/Minute` bis `InpNoTrade1EndHour/Minute`
- Fenster 2: `InpNoTrade2StartHour/Minute` bis `InpNoTrade2EndHour/Minute`
- Fenster 3: `InpNoTrade3StartHour/Minute` bis `InpNoTrade3EndHour/Minute`

Standardmäßig sind kurze Sperren gesetzt (typisch für News-/Rollover-Schutz). Du kannst sie je nach Broker-Serverzeit anpassen.

## Wichtiger Hinweis

„So viele Trades wie möglich“ erhöht auch Kommission/Spread-Kosten und Drawdown-Risiko stark. Starte immer mit Strategy Tester + Demokonto.
