# frozen_string_literal: true

module WorkDecorator
  include DecoratorHelper
  include MODSDecoration

  def title
    return '' if mods.main_title.blank?

    tag.dt('Title') +
      tag.dd(plain_title)
  end

  def names
    return '' if mods.names.blank?

    hsh = {}
    result = []
    mods.names.each do |pn|
      values = hsh[pn.role] ||= []
      values << pn.name
    end
    hsh.each do |k, v|
      result << loop_field(k, v)
    end
    safe_join(result)
  end

  def languages
    loop_field('Languages', mods.languages)
  end

  def date_created
    tag.dt('Date created') +
      tag.dd(mods.date_created&.strftime('%Y-%m-%d'))
  end

  def resource_type
    tag.dt('Resource Type') +
      tag.dd(mods.resource_type&.titleize)
  end

  def genres
    loop_field('Genres', mods.genres)
  end

  def digital_origin
    tag.dt('Digital Origin') +
      tag.dd(mods.digital_origin&.titleize)
  end

  def abstract
    tag.dt('Abstract') +
      tag.dd(plain_description)
  end

  def related_series
    loop_field('Related Items', mods.related_series)
  end

  def subjects
    loop_field('Subjects and keywords', mods.topical_subjects)
  end

  def permanent_url
    tag.dt('Permanent URL') +
      tag.dd(link_to(mods.identifiers&.first))
  end

  def access_condition
    tag.dt('Use and reproduction') +
      tag.dd(mods.access_condition)
  end
end
