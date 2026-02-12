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

# Cron / jobs metrics
cron_json="$(openclaw cron list --json 2>/dev/null || echo '{"jobs":[]}')"
cron_total=$(printf "%s" "$cron_json" | jq '.jobs | length')
cron_enabled=$(printf "%s" "$cron_json" | jq '[.jobs[] | select(.enabled==true)] | length')
cron_err_sum=$(printf "%s" "$cron_json" | jq '[.jobs[].state.consecutiveErrors // 0] | add // 0')

# Sessions / token metrics
sessions_json="$(openclaw sessions list --json 2>/dev/null || echo '{"count":0,"sessions":[]}')"
sessions_total=$(printf "%s" "$sessions_json" | jq '.count // 0')
input_tokens_sum=$(printf "%s" "$sessions_json" | jq '[.sessions[].inputTokens // 0] | add // 0')
output_tokens_sum=$(printf "%s" "$sessions_json" | jq '[.sessions[].outputTokens // 0] | add // 0')

main_input_tokens=$(printf "%s" "$sessions_json" | jq '[.sessions[] | select(.key=="agent:main:main")][0].inputTokens // 0')
main_output_tokens=$(printf "%s" "$sessions_json" | jq '[.sessions[] | select(.key=="agent:main:main")][0].outputTokens // 0')

sanitize_label() {
  echo "$1" | sed -E 's/[^a-zA-Z0-9_:.-]+/_/g'
}

cat > "$TMP" <<EOF
# HELP openclaw_gateway_up OpenClaw gateway reachable (1=yes,0=no)
# TYPE openclaw_gateway_up gauge
openclaw_gateway_up $gateway_up
# HELP openclaw_sessions_active Active sessions (from status)
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
# HELP openclaw_cron_jobs_total Total configured cron jobs
# TYPE openclaw_cron_jobs_total gauge
openclaw_cron_jobs_total $cron_total
# HELP openclaw_cron_jobs_enabled Enabled cron jobs
# TYPE openclaw_cron_jobs_enabled gauge
openclaw_cron_jobs_enabled $cron_enabled
# HELP openclaw_cron_consecutive_errors_sum Sum of consecutive errors across jobs
# TYPE openclaw_cron_consecutive_errors_sum gauge
openclaw_cron_consecutive_errors_sum $cron_err_sum
# HELP openclaw_sessions_total Total known sessions
# TYPE openclaw_sessions_total gauge
openclaw_sessions_total $sessions_total
# HELP openclaw_input_tokens_sum Sum of input tokens across sessions
# TYPE openclaw_input_tokens_sum gauge
openclaw_input_tokens_sum $input_tokens_sum
# HELP openclaw_output_tokens_sum Sum of output tokens across sessions
# TYPE openclaw_output_tokens_sum gauge
openclaw_output_tokens_sum $output_tokens_sum
# HELP openclaw_main_input_tokens Input tokens for main session
# TYPE openclaw_main_input_tokens gauge
openclaw_main_input_tokens $main_input_tokens
# HELP openclaw_main_output_tokens Output tokens for main session
# TYPE openclaw_main_output_tokens gauge
openclaw_main_output_tokens $main_output_tokens
EOF

# Per-job metrics
printf "%s" "$cron_json" | jq -c '.jobs[]?' | while read -r job; do
  name=$(printf "%s" "$job" | jq -r '.name // .id')
  id=$(printf "%s" "$job" | jq -r '.id')
  enabled=$(printf "%s" "$job" | jq -r 'if .enabled then 1 else 0 end')
  status=$(printf "%s" "$job" | jq -r '.state.lastStatus // "unknown"')
  errors=$(printf "%s" "$job" | jq -r '.state.consecutiveErrors // 0')
  duration=$(printf "%s" "$job" | jq -r '.state.lastDurationMs // 0')

  if [ "$status" = "ok" ]; then s=1; elif [ "$status" = "error" ]; then s=0; else s=-1; fi

  safe_name=$(sanitize_label "$name")
  safe_id=$(sanitize_label "$id")

  {
    echo "openclaw_cron_job_enabled{job=\"$safe_name\",job_id=\"$safe_id\"} $enabled"
    echo "openclaw_cron_job_last_status{job=\"$safe_name\",job_id=\"$safe_id\"} $s"
    echo "openclaw_cron_job_consecutive_errors{job=\"$safe_name\",job_id=\"$safe_id\"} $errors"
    echo "openclaw_cron_job_last_duration_ms{job=\"$safe_name\",job_id=\"$safe_id\"} $duration"
  } >> "$TMP"
done

mv "$TMP" "$OUT"
