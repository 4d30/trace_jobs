#!/usr/bin/dash

LOG_TAG="trace.ingest"

log() {
    logger -t "$LOG_TAG" "$*"
}

START_EPOCH=$(date +%s)
START_HUMAN=$(date -Is)

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

[ -f ./.env ] || exit 1
. ./.env

FAIL=0

LOG_ROOT=$DATA_ROOT/logs

Ni=$(find $CAFS_ROOT -type f | wc -l)
#log "START time=$START_HUMAN start_epoch=$START_EPOCH initial_count=$Ni"

: > "$LOG_ROOT/cron.log"
: > "$LOG_ROOT/exceptions.log"

./venv/bin/python -m trace_jobs_ingest >> "$LOG_ROOT/cron.log" 2>&1 || FAIL=1
./venv/bin/python -m trace_jobs_index >> "$LOG_ROOT/cron.log" 2>&1 || FAIL=1
./venv/bin/python -m trace_jobs_http_examples.generate_payloads >> "$LOG_ROOT/cron.log" 2>&1 || FAIL=1

N=$(find $CAFS_ROOT -type f | wc -l)
END_EPOCH=$(date +%s)
END_HUMAN=$(date -Is)

D=$((N - Ni))
DT=$((END_EPOCH - START_EPOCH))

log "END count=$N delta=$D duration_sec=$DT"


if [ "$FAIL" -ne 0 ]; then
    {
        echo "===== CRON LOG ====="
        cat "$LOG_ROOT/cron.log"

        echo ""
        echo "===== EXCEPTIONS ====="
        cat "$LOG_ROOT/exceptions.log"
    } | mail -r "$EMAIL" -s "TRACE ingestion failure" "$EMAIL"

    exit 1
fi


#if [ "$FAIL" -ne 0 ]; then
#    mail -r $EMAIL -s "TRACE ingestion failure" $EMAIL < "$ROOT/cron.log"
#    exit 1
#fi
