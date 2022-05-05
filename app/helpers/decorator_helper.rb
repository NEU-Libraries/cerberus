# frozen_string_literal: true

module DecoratorHelper
  def prefix_field(prefix, field)
    return prefix + field if field.present?

    ''
  end

  def loop_field(title, fields)
    return '' if fields.blank?

    result = tag.dt(title)
    fields.each do |f|
      result += tag.dd(f)
    end
    result
  end
end
