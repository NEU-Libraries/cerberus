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

  COMMUNITY_NARROWING_REFUSED = 'Restricting a community needs DRS administrators — it does not reach the ' \
                                'collections inside it. Nothing has been changed.'

  # A nil level means the write went through and there is nothing to report.
  Result = Struct.new(:level, :message, keyword_init: true) do
    def self.silent = new(level: nil, message: nil)

    def self.refused(message) = new(level: :alert, message: message)
  end

  # @param klass [String] 'Work', 'Collection' or 'Community'.
  # @param id [String] the resource's noid.
  # @param envelope [Hash] the submitted ACL, already parsed by PermissionsForm.
  # @param current_read [Array<String>] the resource's read ACL before this submit.
  # @param actor [User, nil] the acting user.
  def initialize(klass:, id:, envelope:, current_read: [], actor: nil)
    @klass        = klass
    @id           = id
    @envelope     = envelope
    @current_read = Array(current_read)
    @actor        = actor
  end

  # A refusal is reported, not raised: this runs BEFORE the descriptive save in
  # the same submit, so raising would discard valid title/abstract edits.
  def apply!
    return Result.silent if @envelope.blank?

    deferral = narrowing_deferral
    return deferral if deferral

    write(@envelope)
  end

  # The create path. Deliberately not #apply!: there is no cascade one line
  # after a create, and current_read still describes the DESTINATION.
  # See docs/permissions.md.
  def apply_minted!
    submitted = @envelope[:permissions]
    return Result.silent if submitted.blank?

    write(permissions: minted_permissions.merge(submitted.symbolize_keys))
  end

  private

    def write(payload)
      with_stale_retry { AtlasRb.const_get(@klass).metadata(@id, payload) }
      Result.silent
    rescue AtlasRb::PermissionsError => e
      Result.refused(PERMISSIONS_REFUSED.fetch(e.code, e.message))
    end

    # nil when the ordinary write should go ahead. Works never defer; Communities
    # never cascade.
    def narrowing_deferral
      return nil if @klass == 'Work'
      return community_narrowing_refusal if @klass == 'Community'

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

    # Grant lists only -- echoing depositor/proxy_uploader would re-assert
    # attribution this form has no business touching.
    def minted_permissions
      envelope = AtlasRb::Resource.permissions(@id)
      %i[read edit edit_users embargo].index_with { |key| envelope&.dig(key.to_s) }.compact
    end
end
