# frozen_string_literal: true

module Admin
  # Formatting for the ledger. Identifier chips and actor cells come straight
  # from AuditEventsHelper so a NUID reads the same on every surface.
  #
  # One tone per row, carried by --ledger-tone. Adding a kind is one map entry
  # here and one CSS line.
  module LedgerHelper
    KINDS = {
      'request_withdraw'         => { label: 'Withdraw',   icon: 'fa-trash-can' },
      'request_move'             => { label: 'Move',       icon: 'fa-folder-open' },
      'request_restrict'         => { label: 'Restrict',   icon: 'fa-lock' },
      'load_report'              => { label: 'Load',       icon: 'fa-file-import' },
      # "Incomplete" rather than anything stronger: the work is short some pages
      # and needs a person, which is what incomplete_bsi and the triage list
      # already call this condition. Nothing here is a security matter.
      'work_completion_mismatch' => { label: 'Incomplete', icon: 'fa-triangle-exclamation' },
      'visibility_cascade'       => { label: 'Visibility', icon: 'fa-eye-slash' },
      'set_reindex'              => { label: 'Reindex',    icon: 'fa-arrows-rotate' },
      'showcase_promotion'       => { label: 'Showcase',   icon: 'fa-star' },
      'daily_digest'             => { label: 'Digest',     icon: 'fa-book' }
    }.freeze

    # Plain words for the refusal tokens the payload stores. The payload keeps
    # the token so the reason stays queryable; the page speaks English.
    PROMOTION_REASONS = {
      'not_personal_root' => 'The deposit was not in the depositor’s own space, so the form never offered it.',
      'no_showcase'       => 'That community has no showcase for the genre, or the depositor cannot see it.',
      'atlas_forbidden'   => 'Atlas refused the link. The showcase may not be marked featured.'
    }.freeze

    # Narrowing a community does not cascade, and no form offers it — so
    # whoever fulfils the request has to be told the route, or the request is
    # unanswerable. Restricting each collection inside cascades (and confirms)
    # on its own, which is why that is the way rather than a community sweep.
    COMMUNITY_REMEDY = 'Restricting a community does not reach what is inside it. Restrict each collection ' \
                       'within it first — each of those cascades to its own contents — then the community.'

    def ledger_kind_chip(notice)
      descriptor = KINDS.fetch(notice.kind, { label: notice.kind.to_s.humanize, icon: 'fa-circle-dot' })
      tag.span(class: 'ledger-chip') do
        safe_join([tag.i(class: "fa-solid #{descriptor[:icon]}", 'aria-hidden': 'true'), descriptor[:label]])
      end
    end

    # A refusal is a failure, not an association, so it takes the breach tone
    # rather than the showcase one. Everything else is toned by kind alone.
    def ledger_notice_tone(notice)
      return 'refused' if notice.kind == 'showcase_promotion' && notice.detail(:outcome) == 'refused'

      notice.kind
    end

    def ledger_timestamp(time)
      tag.time(time.strftime('%b %-d, %Y · %H:%M'), datetime: time.iso8601, class: 'ledger-age')
    end

    # The object a request is about. Falls back to plain text when the row
    # names a type with no show page.
    def ledger_request_subject(notice)
      label = notice.detail(:subject_title).presence || notice.subject_noid
      path = resource_path_for(notice.detail(:subject_type), notice.subject_noid)
      path ? link_to(label, path, class: 'ledger-subject') : tag.span(label, class: 'ledger-subject')
    end

    # Where the request is actually fulfilled. Each of these already exists and
    # is gated where it lives, which is why the ledger only points at them.
    def ledger_remedy(notice)
      case notice.kind
      when 'request_withdraw' then [resource_path_for('Work', notice.subject_noid), 'Open the work to withdraw it']
      when 'request_move'     then [admin_reparent_path, 'Open the re-parent finder']
      when 'request_restrict' then [edit_path_for(notice.detail(:subject_type), notice.subject_noid),
                                    'Open its permissions']
      end
    end

    # Guidance the fulfiller needs and cannot infer from the row, or nil.
    def ledger_remedy_note(notice)
      COMMUNITY_REMEDY if notice.kind == 'request_restrict' && notice.detail(:subject_type) == 'Community'
    end

    # Only :admin may run a visibility cascade, so only :admin can fulfil a
    # restriction. The devolved-admin tier sees the row and is told as much.
    def ledger_admin_only?(notice) = notice.kind == 'request_restrict'

    # Built from the payload's parts, never from a stored link: the same row has
    # to render as an in-app path here and as an absolute URL in a future mail.
    def ledger_notice_link(notice)
      case notice.kind
      when 'load_report'        then load_report_path_for(notice)
      when 'set_reindex'        then safe_path(:set_path, notice.subject_noid)
      when 'visibility_cascade' then safe_path(:collection_path, notice.subject_noid)
      when 'work_completion_mismatch', 'showcase_promotion' then safe_path(:work_path, notice.subject_noid)
      end
    end

    def ledger_promotion_reason(reason)
      PROMOTION_REASONS[reason.to_s]
    end

    private

      def resource_path_for(type, noid)
        safe_path(:"#{type.to_s.downcase}_path", noid)
      end

      def edit_path_for(type, noid)
        safe_path(:"edit_#{type.to_s.downcase}_path", noid)
      end

      def load_report_path_for(notice)
        slug = notice.detail(:loader_slug)
        report_id = notice.detail(:load_report_id)
        return nil if slug.blank? || report_id.blank?

        loader_load_path(slug, report_id)
      end

      def safe_path(helper, noid)
        return nil if noid.blank? || !respond_to?(helper)

        public_send(helper, noid)
      end
  end
end
