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
  # git rev-parse --git-common-dir answers RELATIVE from the main checkout (".git")
  # and ABSOLUTE from a worktree, so it has to be normalised before anything
  # compares or joins paths with it. Left relative, MAIN_ROOT becomes "." and
  # every path below silently depends on the caller's cwd.
  common="$(cd "$REPO_ROOT" && git rev-parse --git-common-dir)"
  [[ "$common" != /* ]] && common="$REPO_ROOT/$common"
  MAIN_ROOT="$(cd "$(dirname "$common")" && pwd)"

  COMPOSE=(docker compose -p cerberus --project-directory "$MAIN_ROOT"
           --env-file "$MAIN_ROOT/.env"
           -f "$REPO_ROOT/docker-compose.yml"
           -f "$MAIN_ROOT/docker-compose.dev.yml")
  # Gitignored, and carries this host's memory limits. Absent on a fresh machine.
  [[ -f "$MAIN_ROOT/docker-compose.local.yml" ]] && COMPOSE+=(-f "$MAIN_ROOT/docker-compose.local.yml")

  # Where this checkout appears INSIDE the web container, which is not where it
  # appears on the host. The main checkout is bind-mounted onto /home/cerberus/web
  # by docker-compose.dev.yml, so its host path does not resolve in there at all;
  # a worktree is reachable only because the gitignored local compose file mounts
  # the worktrees parent at the same path on both sides. Passing the host path for
  # the main checkout is what `docker exec -w` rejects with:
  #
  #   chdir to cwd ("/home/nakatomi/projects/cerberus") ... no such file or directory
  if [[ "$REPO_ROOT" == "$MAIN_ROOT" ]]; then
    CONTAINER_ROOT=/home/cerberus/web
  else
    CONTAINER_ROOT="$REPO_ROOT"
  fi
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
  local profiles=(--profile atlas-test)
  [[ "$workers" -gt 1 ]] && profiles+=(--profile parallel)

  # Held rather than streamed. Bringing up four services narrates about twenty
  # lines of Creating/Starting/Healthy that say nothing a caller wants while
  # waiting for a spec run — but they are the first thing worth reading when the
  # lane does not come up, so they are kept and replayed on failure.
  local up_output
  # shellcheck disable=SC2046
  if ! up_output="$("${COMPOSE[@]}" "${profiles[@]}" up -d $(lane_services "$workers") 2>&1)"; then
    echo "$up_output" >&2
    return 1
  fi
  [[ -n "${LANE_VERBOSE:-}" ]] && echo "$up_output"

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
    echo "$up_output" >&2
    echo "Check: ${COMPOSE[*]} --profile atlas-test logs atlas-test" >&2
    return 1
  fi
  return 0
}

# Which of the run locks covering these workers are currently held. The locks
# live inside the web container, one file per worker on the same suffix scheme as
# the services (see spec/support/exclusive_run_lock.rb), and the kernel drops
# each one when its run dies — so a held lock means a live run, never a stale
# file. `flock -n ... true` takes and releases in one go, which is exactly the
# question being asked. A container that is not running cannot be holding
# anything, so that case reports nothing rather than guessing.
lane_held_locks() {
  local workers="$1" n suffix path
  docker ps --format '{{.Names}}' | grep -qx cerberus-web-1 || return 0
  for ((n = 1; n <= workers; n++)); do
    [[ "$n" -eq 1 ]] && suffix="" || suffix="-$n"
    path="/tmp/cerberus-rspec-run${suffix}.lock"
    docker exec cerberus-web-1 flock -n "$path" true 2>/dev/null || echo "$path"
  done
}

# Refuses while a run holds one of the locks. The lock serializes rspec against
# rspec, but the lane is a container and tearing it down is not an rspec run, so
# nothing else stands between `--down` and a run whose fixtures are already
# seeded — and the damage reads as a cluster of unrelated failures in whatever
# file was executing, which is the exact confusion the lock exists to prevent.
lane_down() {
  local workers="$1" held
  held="$(lane_held_locks "$workers")"
  if [[ -n "$held" && -z "${LANE_FORCE:-}" ]]; then
    echo "refusing to tear down the test Atlas lane: an rspec run holds" >&2
    echo "$held" | sed 's/^/  /' >&2
    echo >&2
    echo "A run reseeds the lane at startup, so removing it now would destroy" >&2
    echo "the fixtures that run has already written. Wait for it to finish." >&2
    echo "Set LANE_FORCE=1 to tear down anyway." >&2
    return 1
  fi

  # shellcheck disable=SC2046
  "${COMPOSE[@]}" rm -sf $(lane_services "$workers") >/dev/null 2>&1 || true
  echo "released the test Atlas lane"
}
