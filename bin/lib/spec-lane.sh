# shellcheck shell=bash
#
# Shared lifecycle for the test-Atlas lane, sourced by bin/spec and
# bin/parallel-spec.
#
# The lane is containers and the specs are not: rspec runs inside `web` and
# cannot start its own siblings, so every docker call lives on this side of the
# seam and everything needing Rails stays in the container. Both wrappers want
# the same three things — work out the compose invocation, make sure the
# instances are answering, put them away again — so they live here rather than
# drifting apart in two scripts.

# The compose project directory must be the MAIN checkout, never a worktree.
# docker-compose.dev.yml bind-mounts `./` onto the web container's source, and
# `./` resolves against the project directory — so getting this wrong silently
# serves a branch in place of develop, and `web` then fails to boot on whatever
# that branch's Gemfile.lock wants. The base compose file, by contrast, comes
# from the CURRENT checkout, so a branch's own service changes take effect.
lane_init() {
  if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    echo "not inside a git repository." >&2
    return 1
  fi
  MAIN_ROOT="$(dirname "$(cd "$REPO_ROOT" && git rev-parse --git-common-dir)")"

  COMPOSE=(docker compose -p cerberus --project-directory "$MAIN_ROOT"
           --env-file "$MAIN_ROOT/.env"
           -f "$REPO_ROOT/docker-compose.yml"
           -f "$MAIN_ROOT/docker-compose.dev.yml")
  # Gitignored, and carries this host's memory limits. Absent on a fresh machine.
  [[ -f "$MAIN_ROOT/docker-compose.local.yml" ]] && COMPOSE+=(-f "$MAIN_ROOT/docker-compose.local.yml")
  return 0
}

# Worker 1 is the plain atlas-test service; workers 2+ carry a numeric suffix,
# matching the TEST_ENV_NUMBER convention config/environments/test.rb reads.
# Doubles as the host list: a compose service name is its name on the network.
lane_services() {
  local workers="$1" n
  echo "atlas-test"
  for ((n = 2; n <= workers; n++)); do echo "atlas-test-$n"; done
}

# Idempotent: compose leaves an already-running service alone, so a second run in
# the same session costs a no-op rather than a restart.
lane_up() {
  local workers="$1"
  local profiles=(--profile test)
  [[ "$workers" -gt 1 ]] && profiles+=(--profile parallel)

  # shellcheck disable=SC2046
  "${COMPOSE[@]}" "${profiles[@]}" up -d $(lane_services "$workers") >/dev/null

  # Bounded, because an instance that never comes up must fail with its own
  # message rather than hang forever behind a run that was never going to start.
  local want ready host code
  want=$(lane_services "$workers" | wc -l)
  echo -n "waiting for the test Atlas lane "
  for _ in $(seq 1 60); do
    ready=0
    for host in $(lane_services "$workers"); do
      code=$(docker exec cerberus-web-1 bash -lc \
        "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://${host}:3000/reset" 2>/dev/null || true)
      [[ "$code" == "204" ]] && ready=$((ready + 1))
    done
    [[ "$ready" -eq "$want" ]] && break
    echo -n .
    sleep 2
  done
  echo

  if [[ "$ready" -ne "$want" ]]; then
    echo "only $ready of $want test Atlas instances answered GET /reset." >&2
    echo "Check: ${COMPOSE[*]} --profile test logs atlas-test" >&2
    return 1
  fi
  return 0
}

lane_down() {
  local workers="$1"
  # shellcheck disable=SC2046
  "${COMPOSE[@]}" rm -sf $(lane_services "$workers") >/dev/null 2>&1 || true
  echo "released the test Atlas lane"
}
