# frozen_string_literal: true

class CreateAdminNotices < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_notices do |t|
      # What happened: load_report, work_completion_mismatch, visibility_cascade,
      # set_reindex, showcase_promotion, daily_digest. Each kind renders through
      # its own partial, so a new kind is a new partial rather than a new column.
      t.string :kind, null: false
      t.string :subject, null: false
      t.text :body
      # The person the event is attributed to, or nil when there is nobody — a
      # cascade run from a rake task, or the digest. A notice is recorded either
      # way; only the companion inbox message needs somebody to address.
      t.string :actor_nuid
      t.string :subject_noid
      # Kind-specific detail: a cascade tally, a reindex's named failures, the
      # digest's counts and its showcase list. Structured rather than prose
      # because two renderers read it — the ledger builds paths from the noids
      # it holds, and a mailer builds absolute URLs from the same fields.
      t.jsonb :payload, null: false, default: {}
      # The day the event belongs to, in the app's zone. The digest buckets by
      # this rather than by a created_at range, so a job that runs late still
      # writes the right day.
      t.date :occurred_on, null: false

      t.timestamps
    end

    # The daily roll-up's query: every notice of one kind for one day.
    add_index :admin_notices, %i[kind occurred_on]
    # The activity list: filtered by kind, newest first.
    add_index :admin_notices, %i[kind created_at]
    # One digest per day, whatever re-runs. Enforced here rather than in the job
    # so a manual re-run through the rake task cannot double-write a day.
    add_index :admin_notices, %i[kind occurred_on],
              unique: true,
              where: "kind = 'daily_digest'",
              name: 'index_admin_notices_one_digest_per_day'
  end
end
