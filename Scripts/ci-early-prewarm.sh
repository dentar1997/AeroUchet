#!/usr/bin/env bash
# A reusable pre-PR screenshot consumer. This runner stays alive while the
# assistant edits another commit; the final .app must be built from PR HEAD.
set -euo pipefail

RESULTS="$1"
REQUEST_FILE="$2"
mkdir -p "$RESULTS"
exec > >(tee "$RESULTS/early-prewarm.log") 2>&1

REQUEST_T0="$(python3 - "$REQUEST_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    value = json.load(f)["request_epoch"]
assert isinstance(value, int) and value > 0
print(value)
PY
)"
printf '%s\n' "$REQUEST_T0" > "$RESULTS/request-t0-epoch.txt"

mark() {
  local now
  now="$(date -u +%s)"
  printf '{"phase":"%s","epoch":%s,"since_user_request_first_tool_sec":%s}\n' \
    "$1" "$now" "$((now - REQUEST_T0))" | tee -a "$RESULTS/timeline.jsonl"
}

# A single transient GitHub API TLS timeout must not throw away the warm VM.
# Never weaken final-SHA verification; retry the network request instead.
github_retry() {
  local attempt
  for attempt in 1 2 3 4 5 6; do
    if gh "$@"; then return 0; fi
    echo "GitHub API/network error, retry $attempt/6" >&2
    sleep $((attempt * 2))
  done
  return 1
}

mark prewarm.runner_ready
echo "Run: $GITHUB_RUN_ID, branch: $GITHUB_REF_NAME, initial T0: $REQUEST_T0"

# Child process only performs iPadOS boot and exits; the device remains booted.
RUNNER_TRACKING_ID="" nohup bash Scripts/ci-simulator-smoke.sh --preboot "$RESULTS" \
  > "$RESULTS/preboot-bootstrap.log" 2>&1 < /dev/null &
BOOT_PID="$!"
echo "$BOOT_PID" > "$RESULTS/boot.pid"
mark prewarm.boot_requested

# Start observing artifact upload immediately. No wait for build-job conclusion.
# Poll up to 16 minutes; the whole workflow has a separate 20-minute timeout.
BOOT_RECORDED=false
GUI_OPEN_REQUESTED=false
DEADLINE=$(( $(date -u +%s) + 960 ))
PR_SHA=""
RUN_ID=""
while [ "$(date -u +%s)" -lt "$DEADLINE" ]; do
  if [ "$GUI_OPEN_REQUESTED" = false ] && [ -s "$RESULTS/device-udid.txt" ]; then
    # Launch the Simulator GUI while Swift is still compiling on ANOTHER Mac.
    # Avoid cold GUI initialization during the time-critical screenshot stage.
    RUNNER_TRACKING_ID="" nohup open -a Simulator --args \
      -CurrentDeviceUDID "$(cat "$RESULTS/device-udid.txt")" \
      > "$RESULTS/simulator-gui-preopen.log" 2>&1 < /dev/null &
    GUI_OPEN_REQUESTED=true
    mark prewarm.gui_preopen_requested
  fi
  if [ "$BOOT_RECORDED" = false ] && [ -f "$RESULTS/preboot.status" ]; then
    if [ "$(cat "$RESULTS/preboot.status")" = PREBOOTED ]; then
      mark prewarm.boot_ready
      BOOT_RECORDED=true
    fi
  fi
  if [ "$BOOT_RECORDED" = false ] && ! kill -0 "$BOOT_PID" 2>/dev/null && [ ! -f "$RESULTS/preboot.status" ]; then
    echo "Preboot subprocess failed"
    cat "$RESULTS/preboot.log" || true
    exit 1
  fi

  # There must be an OPEN PR from the same branch, not some old branch.
  PR_SHA="$(gh api "repos/$GITHUB_REPOSITORY/pulls?state=open&head=$GITHUB_REPOSITORY_OWNER:$GITHUB_REF_NAME&per_page=10" \
      --jq '.[0].head.sha // empty' 2>/dev/null || true)"
  if [ -n "$PR_SHA" ]; then
    RUN_ID="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs?head_sha=$PR_SHA&event=pull_request&per_page=50" \
      --jq '[.workflow_runs[] | select(.name == "AeroUchet CI") | .id] | first // empty' 2>/dev/null || true)"
  fi

  if [ -n "$PR_SHA" ] && [ -n "$RUN_ID" ]; then
    RUN_SHA="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$RUN_ID" --jq .head_sha 2>/dev/null || true)"
    if [ "$RUN_SHA" != "$PR_SHA" ]; then
      echo "Wrong build commit: $RUN_SHA vs PR $PR_SHA"
      sleep 3
      continue
    fi

    # v4 artifacts become available immediately after upload, without
    # requiring the build job or the whole workflow to finish.
    ARTIFACT_ID="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$RUN_ID/artifacts?per_page=100" \
      --jq '[.artifacts[] | select(.name == "AeroUchet-Simulator" and .expired == false) | .id] | first // empty' 2>/dev/null || true)"
    if [ -n "$ARTIFACT_ID" ]; then
      mark prewarm.app_artifact_visible
      mkdir -p "$RUNNER_TEMP/prewarm-current-app"
      github_retry run download "$RUN_ID" --repo "$GITHUB_REPOSITORY" \
        --name AeroUchet-Simulator --dir "$RUNNER_TEMP/prewarm-current-app"
      test -s "$RUNNER_TEMP/prewarm-current-app/AeroUchet-Simulator.zip"
      LATEST_SHA="$(github_retry api "repos/$GITHUB_REPOSITORY/pulls?state=open&head=$GITHUB_REPOSITORY_OWNER:$GITHUB_REF_NAME&per_page=10" \
        --jq '.[0].head.sha // empty')"
      if [ "$LATEST_SHA" != "$PR_SHA" ]; then
        echo "PR changed during download ($LATEST_SHA vs $PR_SHA): rejecting stale artifact"
        exit 1
      fi
      echo "$PR_SHA" > "$RESULTS/verified-pr-head-sha.txt"
      echo "$RUN_ID" > "$RESULTS/verified-build-run-id.txt"
      echo "$ARTIFACT_ID" > "$RESULTS/verified-build-artifact-id.txt"
      mark prewarm.app_artifact_downloaded
      break
    fi

    OUTCOME="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$RUN_ID/jobs?per_page=100" \
      --jq '[.jobs[] | select(.name == "Build iOS app") | .conclusion] | first // empty' 2>/dev/null || true)"
    case "$OUTCOME" in
      failure|cancelled|timed_out) echo "Build job failed: $OUTCOME"; exit 1 ;;
    esac
  fi
  sleep 3
done

ARCHIVE="$RUNNER_TEMP/prewarm-current-app/AeroUchet-Simulator.zip"
test -s "$ARCHIVE" || { echo "No matching PR artifact before deadline"; exit 1; }
if [ "$BOOT_RECORDED" = false ] && [ -f "$RESULTS/preboot.status" ]; then
  mark prewarm.boot_ready
fi
mark prewarm.capture_started
# Screenshot ONLY the real aircraft-table view for this A/B timing experiment.
bash Scripts/ci-simulator-smoke.sh --aircraft-only "$ARCHIVE" "$RESULTS"
test "$(cat "$RESULTS/status.txt")" = PASS
mark prewarm.aircraft_screenshot_saved

# Double-check after capture: the visual proof must belong to final PR HEAD.
LATEST_SHA="$(github_retry api "repos/$GITHUB_REPOSITORY/pulls?state=open&head=$GITHUB_REPOSITORY_OWNER:$GITHUB_REF_NAME&per_page=10" \
  --jq '.[0].head.sha // empty')"
if [ "$LATEST_SHA" != "$PR_SHA" ]; then
  echo "PR changed after screenshot; not an authentic proof for final SHA"
  exit 1
fi
mark prewarm.pr_sha_verified_after_capture
echo "PASS: early boot + final PR SHA $PR_SHA; screenshots from CI $RUN_ID"
