# frozen_string_literal: true

# Refuses an unfinished deposit — a Work still in_progress, meaning no depositor
# has confirmed it — to everyone except the three people who can act on it.
#
# Read gating does not cover this. An unfinished deposit inherits its parent's
# audience, so one deposited into a public collection is public, while the record
# itself is a placeholder: typically titled with the uploaded filename and
# carrying no subjects. A reader cannot tell it from a finished record.
#
# Included into ApplicationController: the page and the bytes behind it have to
# agree, or hiding the record while its file stays fetchable withholds nothing.
module UnfinishedDepositGate
  extend ActiveSupport::Concern

  private

    # 404 rather than 403: a deposit nobody has confirmed should not have its
    # existence confirmed either.
    def deny_if_unfinished!(work)
      raise Authorizable::ResourceNotFound if work.in_progress && !may_see_unfinished?(work)
    end

    # For the byte routes, which hold a work id rather than the Work. The extra
    # Atlas read is unavoidable: neither a Blob's own gate nor a permissions
    # envelope carries the containing Work's deposit state.
    def deny_if_unfinished_work!(work_id)
      return if work_id.blank?

      work = AtlasRb::Work.find(work_id)
      deny_if_unfinished!(work) if work
    end

    # Staff and admins because they curate. The depositor because the flag clears
    # on *their* next action, and hiding a deposit from the one person who can
    # finish it would strand it.
    def may_see_unfinished?(work)
      return false if effective_user.blank?
      return true if effective_user.admin? || effective_user.member_of?(Permissions::STAFF_EDIT_GROUP)

      effective_user.nuid.present? && effective_user.nuid == work.depositor
    end
end
