# frozen_string_literal: true

module Transformable
  extend ActiveSupport::Concern

  def pretty_resource_permissions(perms)
    perms['read']&.delete('public')
    perms.slice('read', 'edit').flat_map do |key, values|
      permission = key == 'read' ? 'View' : 'Manage'
      values.map { |value| [value, pretty_group(value), permission] }
    end
  end

  def pretty_user_permissions(groups)
    groups.map { |value| [value, pretty_group(value)] }
  end

  def form_group_permissions(perms)
    perms.values.each_with_object({}) do |entry, acc|
      next unless entry['group_id'].present? && entry['ability'].present?

      ability = entry['ability']&.to_sym
      group_id = entry['group_id']
      acc[ability] ||= []
      acc[ability] << group_id
    end
  end

  def form_preparation(raw_permissions)
    @groups = pretty_user_permissions(current_user.groups)
    @public = raw_permissions['read']&.include?('public')
    @embargo = begin
      Date.parse(raw_permissions['embargo']).to_s
    rescue Date::Error, TypeError
      ''
    end
    @permissions = pretty_resource_permissions(raw_permissions)
  end

  def resource_params(resource_key)
    permitted = params.require(resource_key).permit(
      :title,
      :description,
      :embargo,
      permissions: [:group_id, :ability]
    ).to_h
    transform_permissions(permitted, resource_key)
    mass_permissions(permitted)
    add_thumbnail(permitted)
    permitted
  end

  def transform_permissions(permitted, resource_key)
    return unless params[resource_key][:permissions]

    permitted[:permissions] = form_group_permissions(params[resource_key][:permissions])
    if !params[resource_key][:permissions][:embargo].nil?
      permitted[:permissions][:embargo] = params[resource_key][:permissions][:embargo]
    end
  end

  def mass_permissions(permitted)
    return unless params[:mass]

    if params[:mass] == 'public'
      permitted[:permissions][:read] = ['public']
    elsif permitted[:permissions][:read]
      permitted[:permissions][:read].delete('public')
    end
  end
end
