#!/usr/bin/env bash
set -euo pipefail

LOCAL_URL="${LOCAL_URL:-http://localhost:8545}"
REMOTE_URL="${REMOTE_URL:-https://rpc.plume.org}"
JQ_BIN="${JQ_BIN:-jq}"

rpc() {
  local url="$1" method="$2" params_json="${3:-[]}" id="${4:-1}"
  curl -s "$url" -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":$id,\"method\":\"$method\",\"params\":$params_json}"
}

get_block_number() {
  local url="$1" tag="$2"
  local res
  res=$(rpc "$url" eth_getBlockByNumber "[\"$tag\", false]")
  # If method returns error (some nodes may not know 'finalized'), echo empty
  if echo "$res" | grep -q '"error"'; then
    echo ""
    return 0
  fi
  # For 'latest' we can just call eth_blockNumber (faster), but keep unified
  local numHex
  numHex=$(echo "$res" | $JQ_BIN -r '.result.number')
  [[ "$numHex" == "null" || -z "$numHex" ]] && echo "" || printf "%d" "$numHex"
}

hex_to_dec() {
  local h="$1"
  [[ -z "$h" ]] && echo "" && return
  printf "%d" "$h"
}

echo "Comparing local vs remote"
echo " Local : $LOCAL_URL"
echo " Remote: $REMOTE_URL"
echo

# Head (fast) via eth_blockNumber
local_head_hex=$(rpc "$LOCAL_URL" eth_blockNumber | $JQ_BIN -r '.result')
remote_head_hex=$(rpc "$REMOTE_URL" eth_blockNumber | $JQ_BIN -r '.result')

local_head_dec=$(hex_to_dec "$local_head_hex")
remote_head_dec=$(hex_to_dec "$remote_head_hex")

echo "Head:"
printf "  Local head : %s (%s)\n" "$local_head_hex" "$local_head_dec"
printf "  Remote head: %s (%s)\n" "$remote_head_hex" "$remote_head_dec"

if [[ -n "$local_head_dec" && -n "$remote_head_dec" ]]; then
  gap=$(( remote_head_dec - local_head_dec ))
  printf "  Gap: %d blocks (remote - local)\n" "$gap"
fi

# Safe & finalized (may not be supported)
for tag in safe finalized; do
  lh=$(get_block_number "$LOCAL_URL" "$tag")
  rh=$(get_block_number "$REMOTE_URL" "$tag")
  if [[ -n "$lh" || -n "$rh" ]]; then
    echo
    echo "${tag^} block:"
    [[ -n "$lh" ]] && echo "  Local $tag: $lh" || echo "  Local $tag: (unsupported)"
    [[ -n "$rh" ]] && echo "  Remote $tag: $rh" || echo "  Remote $tag: (unsupported)"
    if [[ -n "$lh" && -n "$rh" ]]; then
      printf "  Gap: %d blocks (remote - local)\n" $(( rh - lh ))
    fi
  fi
done

echo
echo "Assessment:"
if [[ -n "${gap:-}" ]]; then
  if (( gap <= 2 && gap >= -2 )); then
    echo "  ✅ Local node appears in sync (head gap ≤ 2)."
  elif (( gap > 2 )); then
    echo "  ⏳ Local node is behind by $gap blocks; if this number shrinks over time, it's catching up."
  else
    echo "  ⚠ Local head ahead of remote by $(( -gap )) blocks (maybe remote lagging or different fork)."
  fi
else
  echo "  Could not compute gap (missing values)."
fi