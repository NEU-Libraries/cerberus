# frozen_string_literal: true

module WorkDecorator
  def title
    tag.dt('Title') +
      tag.dd(mods.main_title.nonSort +
        mods.main_title.title +
        prefix_field(': ', mods.main_title.subtitle) +
        prefix_field(' - ', mods.main_title.partName) +
        prefix_field(', ', mods.main_title.partNumber))
  end

  def names
    mods.plain_name.each do |n|
      # role based title and value
    end
  end

  def languages
    loop_field('Languages', mods.languages)
  end

  def date_created
    tag.dt('Date created') +
      tag.dd(mods.date_created.strftime('%Y-%m-%d'))
  end

  def resource_type
    tag.dt('Resource Type') +
      tag.dd(mods.resource_type.titleize)
  end

  def genres
    loop_field('Genres', mods.genres)
  end

  def digital_origin
    tag.dt('Digital Origin') +
      tag.dd(mods.digital_origin.titleize)
  end

  def abstract
    tag.dt('Abstract') +
      tag.dd(mods.abstract)
  end

  def related_series
    loop_field('Related Items', mods.related_series)
  end

  def subjects
    loop_field('Subjects and keywords', mods.topical_subjects)
  end

  def permanent_url
    tag.dt('Permanent URL') +
      tag.dd(link_to mods.identifiers.first)
  end

  def access_condition
    tag.dt('Use and reproduction') +
      tag.dd(mods.access_condition)
  end

  private

    def prefix_field(prefix, field)
      return prefix + field if field.present?

      ''
    end

    def loop_field(title, fields)
      result = tag.dt(title)
      fields.each do |f|
        result += tag.dd(f)
      end
      result
    end
end
