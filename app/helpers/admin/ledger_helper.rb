# frozen_string_literal: true

module Admin
  # Formatting for the ledger. Identifier chips and actor cells come straight
  # from AuditEventsHelper so a NUID reads the same on every surface.
  #
  # Two tone vocabularies, each driven by a CSS custom property the row sets:
  # a request is toned by its *state* (what is outstanding), a notice by its
  # *kind* (what happened). Adding either is one map entry and one CSS line.
  module LedgerHelper
    REQUEST_KINDS = {
      'withdraw' => { label: 'Withdraw', icon: 'fa-trash-can' },
      'move'     => { label: 'Move',     icon: 'fa-folder-open' },
      'restrict' => { label: 'Restrict', icon: 'fa-lock' }
    }.freeze

    NOTICE_KINDS = {
      'load_report'              => { label: 'Load',       icon: 'fa-file-import' },
      'work_completion_mismatch' => { label: 'Breach',     icon: 'fa-triangle-exclamation' },
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

    def ledger_status_chip(request)
      tag.span(class: "ledger-chip ledger-chip--status ledger-status--#{request.status}") do
        safe_join([tag.i(class: "fa-solid #{status_icon(request.status)}", 'aria-hidden': 'true'),
                   request.status.capitalize])
      end
    end

    def ledger_kind_chip(kind, map)
      descriptor = map.fetch(kind, { label: kind.to_s.humanize, icon: 'fa-circle-dot' })
      tag.span(class: 'ledger-chip') do
        safe_join([tag.i(class: "fa-solid #{descriptor[:icon]}", 'aria-hidden': 'true'), descriptor[:label]])
      end
    end

    def ledger_request_kind_chip(request) = ledger_kind_chip(request.kind, REQUEST_KINDS)
    def ledger_notice_kind_chip(notice)   = ledger_kind_chip(notice.kind, NOTICE_KINDS)

    # A refusal is a failure, not an association, so it takes the breach tone
    # rather than the showcase one. Everything else is toned by kind alone.
    def ledger_notice_tone(notice)
      return 'refused' if notice.kind == 'showcase_promotion' && notice.detail(:outcome) == 'refused'

      notice.kind
    end

    def ledger_age(time)
      return tag.span('—', class: 'text-muted') if time.blank?

      tag.time("#{time_ago_in_words(time)} ago", datetime: time.iso8601, class: 'ledger-age')
    end

    def ledger_timestamp(time)
      tag.time(time.strftime('%b %-d, %Y · %H:%M'), datetime: time.iso8601, class: 'ledger-age')
    end

    # The object a request is about. Falls back to plain text when the row
    # names a type with no show page.
    def ledger_subject_link(request)
      label = request.subject_title.presence || request.subject_noid
      path = resource_path_for(request.subject_type, request.subject_noid)
      path ? link_to(label, path, class: 'ledger-subject') : tag.span(label, class: 'ledger-subject')
    end

    # Where the request is actually fulfilled. Each of these already exists and
    # is gated where it lives, which is why the ledger only points at them.
    def ledger_remedy(request)
      case request.kind
      when 'withdraw' then [resource_path_for('Work', request.subject_noid), 'Open the work to withdraw it']
      when 'move'     then [admin_reparent_path, 'Open the re-parent finder']
      when 'restrict' then [edit_path_for(request.subject_type, request.subject_noid), 'Open its permissions']
      end
    end

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

      def status_icon(status)
        { 'open' => 'fa-circle-dot', 'claimed' => 'fa-user-check', 'resolved' => 'fa-check' }
          .fetch(status, 'fa-circle-dot')
      end

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
