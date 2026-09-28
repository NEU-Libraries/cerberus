# frozen_string_literal: true

# The ACL write for a resource, and the policy deciding whether it may happen.
# PermissionsForm decides what the envelope is; this decides whether Atlas may
# be told. A submit is written, deferred to VisibilityCascadeJob, or refused.
# See docs/permissions.md.
class ResourcePermissions
  include AtlasWrite

  # An unrecognised code falls back to Atlas's own message.
  PERMISSIONS_REFUSED = {
    'visibility_exceeds_parent' => "Visibility wasn't changed — an item can't be more visible " \
                                   'than the collection or community it sits in. Make the ' \
                                   'container public first.'
  }.freeze

  PAST_EMBARGO_REFUSED = "The embargo date wasn't saved — the release date has to be in the future."

  COMMUNITY_NARROWING_REFUSED = 'Restricting a community needs DRS administrators — it does not reach the ' \
                                'collections inside it. Nothing has been changed.'

  # A nil level means the write went through and there is nothing to report.
  Result = Struct.new(:level, :message, keyword_init: true) do
    def self.silent = new(level: nil, message: nil)

    def self.refused(message) = new(level: :alert, message: message)
  end

  # @param solr_type [String] 'Work', 'Collection' or 'Community'. A policy
  #   input, not a dispatch one — the write itself is type-agnostic, and only
  #   the cascade rules below differ by type.
  # @param id [String] the resource's noid.
  # @param envelope [Hash] the submitted ACL, already parsed by PermissionsForm.
  # @param current_read [Array<String>] the resource's read ACL before this submit.
  # @param actor [User, nil] the acting user.
  # @param current_embargo [String, nil] the stored release date, so an
  #   untouched lapsed embargo re-submitted by the form is not refused.
  def initialize(solr_type:, id:, envelope:, current_read: [], actor: nil, current_embargo: nil)
    @solr_type       = solr_type
    @id              = id
    @envelope        = envelope
    @current_read    = Array(current_read)
    @actor           = actor
    @current_embargo = Embargo.release_date(current_embargo)
  end

  # A refusal is reported, not raised: this runs BEFORE the descriptive save in
  # the same submit, so raising would discard valid title/abstract edits.
  def apply!
    return Result.silent if @envelope.blank?

    deferral = narrowing_deferral
    return deferral if deferral

    # The ACL slots only. The form's `permit(:embargo)` leaves a top-level
    # embargo key that nothing reads — PermissionsForm copies the submitted
    # value into permissions[:embargo], which is where it belongs.
    guarded_write(@envelope[:permissions])
  end

  # The create path. Deliberately not #apply!: there is no cascade one line
  # after a create, and current_read still describes the DESTINATION.
  # See docs/permissions.md.
  # The submitted grants alone. A minted child already carries the ACL Atlas
  # gave it from its parent, and an omitted key keeps its stored value, so
  # reading the envelope back to merge onto would only re-send what is there.
  def apply_minted!
    submitted = @envelope[:permissions]
    return Result.silent if submitted.blank?

    guarded_write(submitted.symbolize_keys)
  end

  private

    # A past date is dropped rather than failing the whole write, so the
    # submit's group and visibility changes still land.
    def guarded_write(payload)
      return write(payload) unless past_embargo?(payload)

      rest = payload.except(:embargo)
      result = rest.empty? ? Result.silent : write(rest)
      result.level ? result : Result.refused(PAST_EMBARGO_REFUSED)
    end

    def past_embargo?(payload)
      date = Embargo.release_date(Hash(payload)[:embargo])
      date.present? && !date.future? && date != @current_embargo
    end

    def write(payload)
      with_stale_retry { AtlasRb::Resource.set_permissions(@id, payload) }
      Result.silent
    rescue AtlasRb::PermissionsError => e
      Result.refused(PERMISSIONS_REFUSED.fetch(e.code, e.message))
    end

    # nil when the ordinary write should go ahead. Works never defer; Communities
    # never cascade.
    def narrowing_deferral
      return nil if @solr_type == 'Work'
      return community_narrowing_refusal if @solr_type == 'Community'

      outcome = NarrowingRequest.call(noid: @id, current_read: @current_read,
                                      permissions: @envelope[:permissions] || {}, actor: @actor)
      return nil unless outcome.handled?

      Result.new(level: outcome.dispatched? ? :notice : :alert, message: outcome.message)
    end

    # Server-side backstop: the form offers Private to administrators only.
    def community_narrowing_refusal
      submitted = Array(@envelope.dig(:permissions, :read))
      return nil unless Permissions.narrowing?(current: @current_read, submitted: submitted)
      return nil if @actor&.admin?

      Result.refused(COMMUNITY_NARROWING_REFUSED)
    end
end
