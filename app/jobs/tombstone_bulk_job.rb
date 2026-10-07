# frozen_string_literal: true

# Restores or permanently deletes the tombstoned items checked on the registry,
# in an order Atlas accepts, then records the run in one ledger entry. See
# docs/admin.md ("Bulk restore and bulk delete").
#
# Atlas refuses to restore a child under a tombstoned parent, and refuses to
# purge a container that still holds members. So restores run shallowest
# first and deletes deepest first, measured within the selection.
class TombstoneBulkJob < ApplicationJob
  queue_as :default

  ACTIONS = %w[restore delete].freeze

  Item = Struct.new(:noid, :uuid, :parent_uuid, :klass, :title, keyword_init: true)

  def perform(action:, noids:)
    items = ordered(resolve(noids), action)
    done = []
    failures = []

    items.each do |item|
      outcome = run(action, item.noid)
      if outcome == :ok
        done << { 'noid' => item.noid, 'type' => item.klass, 'title' => item.title }
      else
        failures << "#{item.klass} #{item.noid}: #{failure_text(outcome)}"
      end
    end

    skipped = noids - items.map(&:noid)
    report(action: action, done: done, failures: failures, skipped: skipped)
  end

  private

    def run(action, noid)
      action == 'delete' ? TombstoneRegistryAction.purge(noid) : TombstoneRegistryAction.restore(noid)
    end

    # Only records still tombstoned are acted on: an item restored or purged
    # since the page was rendered drops out and is reported as skipped.
    def resolve(noids)
      terms = noids.map { |noid| "id-#{noid}" }.join(',')
      response = Blacklight.default_index.search(
        q: '*:*', rows: noids.size, fl: 'id,alternate_ids_ssim,a_member_of_ssi,internal_resource_tesim,title_tsim',
        fq: ['tombstoned_bsi:true', "{!terms f=alternate_ids_ssim}#{terms}"]
      )
      response.documents.map { |doc| item_from(doc) }
    end

    def item_from(doc)
      Item.new(noid: Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-'), uuid: doc.id,
               parent_uuid: doc['a_member_of_ssi'].to_s.delete_prefix('id-').presence,
               klass: doc.klass_type, title: Array(doc['title_tsim']).first.to_s)
    end

    def ordered(items, action)
      by_uuid = items.index_by(&:uuid)
      depth = ->(item) { depth_of(item, by_uuid) }
      sorted = items.sort_by { |item| [depth.call(item), item.noid] }
      action == 'delete' ? sorted.reverse : sorted
    end

    # How many of the item's ancestors are also in the selection. The guard
    # stops a membership cycle from looping.
    def depth_of(item, by_uuid)
      depth = 0
      parent = by_uuid[item.parent_uuid]
      while parent && depth < by_uuid.size
        depth += 1
        parent = by_uuid[parent.parent_uuid]
      end
      depth
    end

    def failure_text(outcome)
      outcome == :has_children ? 'still holds members' : 'Atlas refused it'
    end

    def report(action:, done:, failures:, skipped:)
      CompletionNotice.deliver(
        kind:    'tombstone_bulk',
        to_nuid: Current.nuid,
        subject: subject_for(action, done, failures),
        body:    body_for(action, done, failures, skipped),
        payload: { action: action, done: done, failures: failures, skipped: skipped }
      )
    end

    def subject_for(action, done, failures)
      verb = action == 'delete' ? 'Bulk delete' : 'Bulk restore'
      total = done.size + failures.size
      "#{verb}: #{done.size} of #{total} item#{'s' unless total == 1} #{action == 'delete' ? 'deleted' : 'restored'}"
    end

    def body_for(action, done, failures, skipped)
      verb = action == 'delete' ? 'permanently deleted' : 'restored'
      lines = ["#{verb.capitalize}:", *done.map { |item| "#{item['type']} #{item['noid']} — #{item['title']}" }]
      lines += ['', "These could not be #{verb}:", *failures] if failures.any?
      lines += ['', 'No longer tombstoned when the run started, so left alone:', *skipped] if skipped.any?
      lines.join("\n")
    end
end
