# frozen_string_literal: true

module Transformable
  extend ActiveSupport::Concern

  # Helper methods for pretty group transformation

  def pretty_resource_permissions(perms)
    perms['read']&.delete('public')
    perms.slice(
      'read', 'edit'
    ).flat_map do |key, values|
      permission = key == 'read' ? 'View' : 'Manage'
      values.map { |value| [value, pretty_group(value), permission] }
    end
  end

  def pretty_user_permissions(groups)
    groups.map { |value| [value, pretty_group(value)] }
  end

  def form_group_permissions(perms)
    perms.values.each_with_object({}) do |entry, acc|
      ability = entry['ability'].to_sym
      group_id = entry['group_id']
      acc[ability] ||= []
      acc[ability] << group_id
    end
  end

end
