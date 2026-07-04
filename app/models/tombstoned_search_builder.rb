# frozen_string_literal: true

# The inverse of the catalog's default tombstone filter, for the admin
# "restore a withdrawal" registry.
#
# Every SearchBuilder inherits CatalogController.default_solr_params, whose fq
# carries `-tombstoned_bsi:true` (so withdrawn objects never surface in normal
# discovery). A listing of *tombstoned* items therefore can't just AND
# `tombstoned_bsi:true` onto the query — it would contradict the inherited
# exclusion and return nothing. This builder appends one final processor step
# that runs after default_solr_parameters has populated fq: it drops the
# exclusion clause and adds the inclusion in its place. The FileSet / Blob /
# Delegate exclusions in the same default fq are left intact (we only want
# top-level resources).
#
# Gated discovery still runs (inherited from SearchBuilder), but short-circuits
# for admins, and this builder is only ever driven from the admin-gated
# TombstonedItems service — so an admin sees every withdrawn resource.
class TombstonedSearchBuilder < SearchBuilder
  self.default_processor_chain += [:only_tombstoned]

  def only_tombstoned(solr_parameters)
    solr_parameters[:fq] = Array(solr_parameters[:fq]).reject { |f| f == '-tombstoned_bsi:true' }
    solr_parameters[:fq] << 'tombstoned_bsi:true'
  end
end
