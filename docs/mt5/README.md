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
  - `InpMaxOpenPositionsTotal = 6`
  - `InpMaxOpenPositionsPerSide = 3`
- Minimale Pause zwischen Entries (`InpMinSecondsBetweenEntries = 2`)
- Session standardmäßig 24h (`InpStartHour = 0`, `InpEndHour = 24`)

## Aktives Scalping-Trade-Management

- Enge ATR-Stops/Targets (SL 0.55x ATR, TP 0.85x ATR)
- Break-even
- ATR-Trailing-Stop
- Exit auf Gegensignal
- Zeitbasiertes Schließen nach maximaler Haltedauer


## Preset-Profile (neu)

- `InpScalpPreset = PRESET_CONSERVATIVE` → vorsichtiger, weniger Trades
- `InpScalpPreset = PRESET_BALANCED` → Standard
- `InpScalpPreset = PRESET_AGGRESSIVE` → maximale Aktivität
- `InpScalpPreset = PRESET_CUSTOM` → nutzt exakt deine eigenen Input-Werte

Tipp für deinen Wunsch „ja gerne":
- Für sehr viele Trades: `PRESET_AGGRESSIVE`
- Mit fixer Lot: `InpLotMode = LOT_MODE_FIXED_LOT` und z. B. `InpFixedLotSize = 0.01`

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

## Wichtiger Hinweis

„So viele Trades wie möglich“ erhöht auch Kommission/Spread-Kosten und Drawdown-Risiko stark. Starte immer mit Strategy Tester + Demokonto.
