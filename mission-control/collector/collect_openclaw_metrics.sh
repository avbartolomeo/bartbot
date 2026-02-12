#!/usr/bin/env bash
set -euo pipefail
OUT="/home/alejandro/.openclaw/workspace/mission-control/textfile/openclaw.prom"
TMP="${OUT}.tmp"

status_out="$(openclaw status --deep 2>/dev/null || true)"

gateway_up=0
sessions_active=0
tokens_used=0
tokens_total=0
tokens_pct=0
telegram_ok=0

if [ -n "$status_out" ]; then
  gateway_up=1
  sessions_active=$(printf "%s\n" "$status_out" | sed -n 's/.*Sessions\s*│\s*\([0-9]\+\) active.*/\1/p' | head -n1)
  sessions_active=${sessions_active:-0}

  token_field=$(printf "%s\n" "$status_out" | grep -Eo '[0-9]+k/[0-9]+k \([0-9]+%\)' | head -n1 || true)
  if [ -n "$token_field" ]; then
    tokens_used=$(echo "$token_field" | sed -E 's#([0-9]+)k/([0-9]+)k.*#\1#')
    tokens_total=$(echo "$token_field" | sed -E 's#([0-9]+)k/([0-9]+)k.*#\2#')
    tokens_pct=$(echo "$token_field" | sed -E 's#.*\(([0-9]+)%\).*#\1#')
  fi

  if printf "%s\n" "$status_out" | grep -q 'Telegram .*│ OK'; then
    telegram_ok=1
  fi
fi

cat > "$TMP" <<EOF
# HELP openclaw_gateway_up OpenClaw gateway reachable (1=yes,0=no)
# TYPE openclaw_gateway_up gauge
openclaw_gateway_up $gateway_up
# HELP openclaw_sessions_active Active sessions
# TYPE openclaw_sessions_active gauge
openclaw_sessions_active $sessions_active
# HELP openclaw_context_used_k_tokens Used context tokens in K (first active session)
# TYPE openclaw_context_used_k_tokens gauge
openclaw_context_used_k_tokens $tokens_used
# HELP openclaw_context_total_k_tokens Total context tokens in K (first active session)
# TYPE openclaw_context_total_k_tokens gauge
openclaw_context_total_k_tokens $tokens_total
# HELP openclaw_context_used_percent Context usage percent (first active session)
# TYPE openclaw_context_used_percent gauge
openclaw_context_used_percent $tokens_pct
# HELP openclaw_telegram_ok Telegram channel health (1=OK,0=not OK)
# TYPE openclaw_telegram_ok gauge
openclaw_telegram_ok $telegram_ok
EOF

mv "$TMP" "$OUT"
