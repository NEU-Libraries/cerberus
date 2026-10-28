# Fixity

Atlas records a SHA-512 for every stored file when it writes it. A **fixity
check** re-hashes the stored bytes later and compares them with that digest.
Atlas's own `docs/fixity.md` is the reference for the checker and for how a
result is recorded. This page covers the Cerberus side: the service that runs
the checker, its secret, and the two places Cerberus shows the results.

Source files:

- `docker-compose.yml` and `docker-compose.dev.yml` (the `fixity` service)
- `app/helpers/work_health_helper.rb` (`work_health_fixity`, the Health tab line)
- `app/models/fixity_search_builder.rb` (the three lists)
- `app/services/fixity_report.rb` (the search and its order)
- `app/controllers/admin/fixity_controller.rb` and `app/views/admin/fixity/`
- `app/helpers/admin/fixity_helper.rb` (the report's cells)

## The checker runs as its own service

The `fixity` service runs the Atlas image with `bin/fixity-entrypoint.sh` as
its entrypoint. The entrypoint never exits. It wakes every 15 minutes, and on
the first wake inside the nightly window it sweeps the objects Atlas says are
due. Each result goes to Atlas's `POST /fixity_checks`. Atlas appends the
result to the object's OCFL log and re-indexes the owning Work.

**Each object is checked once per cycle.** An object is due again
`FIXITY_CYCLE` after its last check, 90 days by default. Never-checked objects
come first, then the oldest checks. A night that cannot finish the due list
leaves the rest for the next night.

**One sweep a window.** A sweep that finishes, by the list, the window's end
or the budget, closes the window, and later wakes that night do nothing. A
sweep that Atlas refuses or cannot be reached is retried on the next wake. The
checker remembers the window only inside its container, so a restart sweeps
again at once. The cycle keeps that sweep from re-hashing what was just
checked.

In steady state a night reads about the repository's size divided by the cycle
in days: 10 TB on a 90-day cycle is about 110 GB a night.

- **Run exactly one replica.** Two checkers race over the same objects.
- **Keep the storage mount `:ro`.** The checker only reads. The entrypoint logs
  a warning when a root is writable.
- **Keep it on the same tag as `atlas`.** Both read `${ATLAS}`, so they move
  together. Pin `ATLAS` to a version in `.env`: the registry's `:latest` can be
  a stale build.
- **The window is whole UTC hours, end exclusive.** It defaults to 01:00 to
  07:00. Set `FIXITY_WINDOW_START` and `FIXITY_WINDOW_END` to change it.
- **Keep the cycle well under 12 months.** The admin report counts a Work
  unchecked for 12 months as overdue, so a longer cycle lists every Work there.

To watch a sweep in dev, set the window to the current UTC hour in `.env`, and
recreate the service with the full `up` chain. Recreating it also clears the
window it remembers. A sweep re-hashes only what is due, so on a stack checked
within the cycle, set `FIXITY_CYCLE=0` as well to force a full pass. Then read
the log:

```bash
docker compose logs -f fixity
```

## The secret

The checker signs in as Atlas's `:fixity_checker` principal (NUID `000000098`).
Its secret pairs with that principal only. It must not reuse `system_token`,
which can mint a token for anyone.

1. Atlas: set `fixity_token` in Atlas's credentials. Run `bin/rails
   atlas:fixity:checker_user` once per environment. `reset:data` creates the
   principal in dev.
2. Cerberus: put the same value in `.env` as `ATLAS_FIXITY_TOKEN`. Compose
   passes it to the `fixity` service as `FIXITY_TOKEN`. Cerberus itself never
   sends it.

Until both ends are set, every sweep logs `due list answered 401` and the loop
sleeps until the next one. The service is harmless while unconfigured, which is
why CI's plain `up` can start it.

## Staging

Staging runs a hand-maintained Swarm stack, so the service goes into that YAML
by hand:

```yaml
  fixity:
    image: nakatomi/atlas_web:<same tag as atlas>
    entrypoint: ["/home/atlas/web/bin/fixity-entrypoint.sh"]
    environment:
      ATLAS_URL: 'http://atlas:3000/'
      FIXITY_TOKEN_FILE: /run/secrets/atlas_fixity_token
      FIXITY_CYCLE: 90d
      OCFL_EXTRA_ROOTS: <the same value the atlas service has>
    secrets: [atlas_fixity_token]
    volumes:
      - <atlas storage volume>:/home/atlas/storage:ro
    deploy:
      replicas: 1
      restart_policy:
        condition: any
      resources:
        limits:
          cpus: '1'
          memory: 256M
```

- **Swarm ignores `restart:`.** `deploy.restart_policy` replaces it.
- **Mount every extra storage root `:ro` as well.** An unmounted root's objects
  are never checked.
- **Set `FIXITY_BUDGET`, such as `500GB`, if reads cost money.** It bounds a
  whole night, not one wake. Without it, the cycle and the window's end bound
  a night's reads.

## The Health tab line

The Fixity line on a Work's Health tab reads the `fixity` block of the health
check. [Work health](work-health.md) tables its keys.

| State | Line |
|---|---|
| `result` is `fail` | "Failed. A stored file no longer matches its recorded digest." |
| `result` is set, and `never_checked` is above 0 | "Partly verified: N of M files not yet checked." |
| `result` is `pass`, with `last_checked_at` | "Verified <date>, passed." |
| anything else, including no block | "Not yet checked." |

A fail outranks a partial sweep. A recorded fail also grades the Work red, with
a `fixity_failed` finding per object; the line explains the grade.

## The admin report

`/admin/fixity` lists Works in three disjoint states, one tab each:

| Tab | Filter |
|---|---|
| Failed | `work_fixity_result_ssi:fail` |
| Not fully verified in 12 months | passed, and the oldest check is over 12 months old or absent |
| Never verified | no `work_fixity_result_ssi` at all |

The filters read the per-Work rollup that Atlas indexes. A FileSet or Blob
document is hidden from the catalog, so a per-object field cannot answer for a
Work. Atlas leaves `work_fixity_checked_at_dtsi` absent while any object is
unchecked. So the overdue filter also matches the absent date, or a partly
checked Work would sit on no list.

**The fields are for staff only.** Do not add them to the public catalog as
facets or display fields.

**The report is `:admin` only.** It reads Solr, and gated discovery shows the
devolved-admin tier only what its groups can see. A short list would then read
as a healthy repository.

**Withdrawn Works are not listed.** The report keeps the catalog's tombstone
exclusion. A withdrawn Work's bytes are still checked, and its Health tab still
shows the result.

The suite cannot seed a recorded check, because only the checker principal may
post one. `spec/requests/admin/fixity_spec.rb` covers the never-verified list
end to end, and `spec/models/fixity_search_builder_spec.rb` covers the other
two lists at the filter.
