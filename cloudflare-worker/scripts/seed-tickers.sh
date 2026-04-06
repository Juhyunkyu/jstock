#!/usr/bin/env bash
# ============================================================================
# seed-tickers.sh — Seed the CACHE_KV warm:tickers key with curated tickers
# ============================================================================
#
# Usage:
#   cd cloudflare-worker
#   bash scripts/seed-tickers.sh
#
# Prerequisites:
#   - wrangler CLI installed and authenticated (`wrangler login`)
#   - Run from the cloudflare-worker/ directory (where wrangler.toml lives)
#
# What this does:
#   Stores a JSON array of 150 popular US stock tickers in Cloudflare KV
#   under the key "warm:tickers". The Worker's cron handler reads this key
#   to pre-cache Finnhub quotes for fast client responses.
#
# Ticker selection (150 total, curated for Korean retail investors):
#
#   Category                    Count  Tickers
#   ─────────────────────────── ───── ─────────────────────────────────────────
#   빅테크/Mag7+                 (12)  AAPL ADBE AMZN AVGO CRM GOOGL META MSFT
#                                      NFLX NVDA ORCL TSLA
#   반도체                       (15)  ADI AMAT AMD ARM ASML CDNS INTC KLAC
#                                      LRCX MPWR MRVL MU ON QCOM TSM
#   AI/클라우드                  (12)  AI CRWD DDOG DELL HPE NET NOW PANW PLTR
#                                      SMCI SNOW ZS
#   우주항공                      (8)  ASTS AXON KTOS LDOS LHX LUNR RDW RKLB
#   방산                          (8)  ACHR BA GD GE HWM LMT NOC RTX
#   레버리지 ETF (인버스 제외)    (8)  BULZ FNGU SOXL SPXL TECL TNA TQQQ UPRO
#   인기 ETF                     (15)  ARKK EEM IBIT IVV JEPI KWEB QQQ SCHD
#                                      SMH SOXX SPY VGT VOO VTI XLK
#   성장/트렌딩                  (15)  ABNB AFRM COIN CRWV DUOL HIMS HOOD IONQ
#                                      MSTR SHOP SOFI SPOT SQ TOAST UBER
#   EV/모빌리티                   (8)  F GM LCID LI NIO RIVN TM XPEV
#   에너지                        (8)  CEG CVX ENPH FSLR OXY SLB VST XOM
#   헬스케어                     (10)  ABBV DXCM ISRG JNJ LLY MRK MRNA PFE
#                                      UNH VRTX
#   배당/가치                    (10)  EPD KO MAIN MCD MO O PG PM T VZ
#   대형 금융/기타               (10)  BLK COST DIS GS HD JPM MA NKE V WMT
#   중국/ADR                      (5)  BABA BIDU JD PDD TME
#   지수/채권/원자재 ETF          (6)  DIA GLD IWM SLV TLT URA
#   ─────────────────────────── ─────
#   Total                       (150)
#
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKERS_FILE="$SCRIPT_DIR/tickers.json"

if [[ ! -f "$TICKERS_FILE" ]]; then
  echo "Error: tickers.json not found at $TICKERS_FILE"
  exit 1
fi

TICKERS="$(cat "$TICKERS_FILE")"
COUNT="$(echo "$TICKERS" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"

echo "Seeding warm:tickers with $COUNT tickers..."
echo ""

npx wrangler kv key put \
  --remote \
  --binding=CACHE_KV \
  "warm:tickers" \
  "$TICKERS"

echo ""
echo "Done. $COUNT tickers seeded successfully."
echo "Verify with:"
echo "  npx wrangler kv key get --remote --binding=CACHE_KV 'warm:tickers'"
