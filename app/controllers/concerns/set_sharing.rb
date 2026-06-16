# frozen_string_literal: true

# Sharing-tab (ACL) handling for SetsController: reads a Compilation's ACL into
# the form, writes the replacement back via Compilation.update(permissions:),
# and nudges newly-added grantees through the inbox. The controller gates this
# to the owner/admin; Atlas re-checks every write regardless.
module SetSharing
  extend ActiveSupport::Concern

  private

    # Pre-fill the Sharing tab from the Set's ACL. The `public` token lives in
    # read_groups; the widget shows the real groups; edit_users render as chips.
    def prepare_sharing_form
      read_groups = Array(@set['read_groups'])
      @public = read_groups.include?('public')
      @groups = Array(current_user&.groups).map { |raw| [raw, pretty_group(raw)] }
      @permissions = group_permission_rows(read_groups)
      @edit_user_grants = Array(@set['edit_users']).map { |nuid| { nuid: nuid, name: NuidResolver.name_for(nuid) } }
    end

    # [group_id, label, 'View'|'Manage'] rows for the shared permissions widget.
    def group_permission_rows(read_groups)
      read_groups.reject { |group| group == 'public' }.map { |group| [group, pretty_group(group), 'View'] } +
        Array(@set['edit_groups']).map { |group| [group, pretty_group(group), 'Manage'] }
    end

    def update_sharing
      return head :forbidden unless @owned

      before = current_acl
      permissions = build_permissions
      AtlasRb::Compilation.update(@set['id'], permissions: permissions)
      notify_new_grants(before, permissions)
      redirect_to set_path(@set['id']), notice: 'Sharing updated.'
    rescue AtlasRb::CompilationError => e
      flash.now[:alert] = e.message
      prepare_sharing_form
      render :edit, status: :unprocessable_content
    end

    # The ACL replacement sent to Atlas: read/edit group lists (read carries the
    # `public` token when public) plus the individual edit_users NUIDs.
    def build_permissions
      groups = parse_group_permissions(params.dig(:set, :permissions))
      read = groups[:read]
      read << 'public' if params[:mass] == 'public'
      { read: read.uniq, edit: groups[:edit], edit_users: submitted_edit_users }
    end

    # Stacked-input rows (mirrors the object permissions widget): each row is
    # { group_id, ability }; blank rows are skipped.
    def parse_group_permissions(rows)
      acc = { read: [], edit: [] }
      return acc if rows.blank?

      rows.each_value do |row|
        next if row['group_id'].blank? || row['ability'].blank?

        (row['ability'] == 'edit' ? acc[:edit] : acc[:read]) << row['group_id']
      end
      acc.transform_values(&:uniq)
    end

    def submitted_edit_users
      Array(params.dig(:set, :edit_users)).map { |nuid| nuid.to_s.strip }.compact_blank.uniq
    end

    def current_acl
      { read: Array(@set['read_groups']), edit: Array(@set['edit_groups']), edit_users: Array(@set['edit_users']) }
    end

    # An inbox nudge per newly-added grantee (individuals + groups). Diffed
    # against the prior ACL so re-saving an unchanged share notifies no one.
    # `public` is not a grantee, so it never triggers a message.
    def notify_new_grants(before, after)
      (Array(after[:edit_users]) - Array(before[:edit_users])).each { |nuid| share_message(recipient_nuid: nuid) }
      added_grant_groups(before, after).each { |group| share_message(recipient_group: group) }
    end

    def added_grant_groups(before, after)
      added_read = Array(after[:read]) - Array(before[:read]) - ['public']
      added_edit = Array(after[:edit]) - Array(before[:edit])
      (added_read + added_edit).uniq
    end

    def share_message(recipient_nuid: nil, recipient_group: nil)
      sharer = current_user.try(:name).presence || current_user.nuid
      Message.create(
        sender_nuid:     attributed_nuid,
        recipient_nuid:  recipient_nuid,
        recipient_group: recipient_group,
        subject:         'A set was shared with you',
        body:            "#{sharer} shared the set “#{@set['title']}” with you."
      )
    end
end
