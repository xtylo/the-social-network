#!/usr/bin/env bash
# Prints CloudWatch metrics (1-minute points, UTC) for the last N minutes of the load test.
# Usage (in a terminal prepared with `source scripts/aws-env.sh`): ./scripts/aws-metrics.sh [minutes, default 30]
set -euo pipefail

MINUTES="${1:-30}"
START="$(date -u -d "-${MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ)"
END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# show <label> <namespace> <dimension Name=..,Value=..> <metric> <statistic: Sum | Average | Maximum | p99>
show() {
  local label=$1 namespace=$2 dimension=$3 metric=$4 stat=$5
  local args field
  if [[ $stat == p* ]]; then
    args=(--extended-statistics "$stat"); field="ExtendedStatistics.$stat"
  else
    args=(--statistics "$stat"); field="$stat"
  fi
  printf '\n== %s\n' "$label"
  aws cloudwatch get-metric-statistics \
    --namespace "$namespace" --metric-name "$metric" --dimensions "$dimension" \
    --start-time "$START" --end-time "$END" --period 60 "${args[@]}" \
    --query "sort_by(Datapoints, &Timestamp)[].[Timestamp, $field]" --output text
}

RECO="Name=FunctionName,Value=tsn-reco"
DB="Name=DBInstanceIdentifier,Value=tsn-db"

echo "CloudWatch metrics from $START to $END"
show "Rust Lambda: invocations per minute"        AWS/Lambda "$RECO" Invocations          Sum
show "Rust Lambda: average duration (ms)"         AWS/Lambda "$RECO" Duration             Average
show "Rust Lambda: p99 duration (ms)"             AWS/Lambda "$RECO" Duration             p99
show "Rust Lambda: max concurrent executions"     AWS/Lambda "$RECO" ConcurrentExecutions Maximum
show "Rust Lambda: throttles"                     AWS/Lambda "$RECO" Throttles            Sum
show "Rust Lambda: errors"                        AWS/Lambda "$RECO" Errors               Sum
show "RDS: max CPU (%)"                           AWS/RDS    "$DB"   CPUUtilization       Maximum
show "RDS: max open connections"                  AWS/RDS    "$DB"   DatabaseConnections  Maximum
