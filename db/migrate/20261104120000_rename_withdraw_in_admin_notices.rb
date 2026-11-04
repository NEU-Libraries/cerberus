# frozen_string_literal: true

# Ledger rows are write-once, so the rows already written keep the old names
# unless this rewrites them: a depositor's deletion request, and the list a
# cascade delete records for a console restore. See docs/admin.md.
class RenameWithdrawInAdminNotices < ActiveRecord::Migration[8.1]
  def up
    rename_request(from: 'withdraw', to: 'delete')
    rename_cascade_key(from: 'withdrawn', to: 'tombstoned')
  end

  def down
    rename_request(from: 'delete', to: 'withdraw')
    rename_cascade_key(from: 'tombstoned', to: 'withdrawn')
  end

  private

  def rename_request(from:, to:)
    execute <<~SQL.squish
      UPDATE admin_notices
      SET kind = #{quote("request_#{to}")},
          subject = regexp_replace(subject, #{quote("^Request to #{from} ")}, #{quote("Request to #{to} ")})
      WHERE kind = #{quote("request_#{from}")}
    SQL
  end

  def rename_cascade_key(from:, to:)
    execute <<~SQL.squish
      UPDATE admin_notices
      SET payload = (payload - #{quote(from)}) || jsonb_build_object(#{quote(to)}, payload -> #{quote(from)})
      WHERE kind = 'tombstone_cascade' AND payload ? #{quote(from)}
    SQL
  end

  def quote(value) = connection.quote(value)
end
