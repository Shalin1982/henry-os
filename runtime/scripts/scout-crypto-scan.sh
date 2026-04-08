#!/bin/bash
# SCOUT Crypto Opportunity Scanner
# Runs every 6 hours to find crypto/DeFi opportunities

LOG_FILE="$HOME/.openclaw/logs/scout-crypto.log"
MEMORY_FILE="$HOME/.openclaw/workspace/memory/$(date +%Y-%m-%d).md"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== SCOUT Crypto Scan Starting ==="

# Check CoinGecko for new listings (using their public API)
log "Checking CoinGecko new listings..."
curl -s "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false" 2>/dev/null | \
    python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    new_coins = [c for c in data if c.get('market_cap', 0) > 0 and c.get('market_cap', 0) < 100000000]  # Under $100M MC
    for coin in new_coins[:10]:
        print(f\"COIN: {coin['name']} ({coin['symbol'].upper()}) - MC: ${coin.get('market_cap', 0):,.0f} - Price: ${coin.get('current_price', 0)}\")
except:
    pass
" | tee -a "$LOG_FILE"

# Check for high-momentum coins (24h change >20%)
log "Checking high-momentum coins..."
curl -s "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=24h" 2>/dev/null | \
    python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    movers = [c for c in data if c.get('price_change_percentage_24h', 0) > 20 and c.get('market_cap', 0) > 10000000]
    for coin in movers[:5]:
        print(f\"MOVER: {coin['name']} ({coin['symbol'].upper()}) +{coin.get('price_change_percentage_24h', 0):.1f}% - MC: ${coin.get('market_cap', 0):,.0f}\")
except:
    pass
" | tee -a "$LOG_FILE"

# Log to memory
{
    echo ""
    echo "## SCOUT Crypto Scan: $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "Coins scanned: CoinGecko top 250"
    echo "Focus: New listings, high momentum, business use cases"
    echo ""
    echo "### Findings:"
    tail -20 "$LOG_FILE" | grep -E "^(COIN|MOVER):"
    echo ""
} >> "$MEMORY_FILE" 2>/dev/null

log "=== SCOUT Crypto Scan Complete ==="
log ""
