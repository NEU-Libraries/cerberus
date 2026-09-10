# frozen_string_literal: true

# The simple-form descriptive fields (title, abstract, keywords) for the
# Metadata tab. Every edit MERGES into the resource's existing MODS, never
# replaces it, so curated nodes the form does not own survive. See
# docs/deposit.md.
module DescriptiveMetadata
  extend ActiveSupport::Concern
  include AtlasWrite

  def descriptive_params(resource_key, keywords: false)
    raw = params.require(resource_key).permit(:title, :description, keywords: [])
    {
      title:       raw[:title],
      description: raw[:description],
      keywords:    keywords ? clean_keywords(raw[:keywords]) : nil
    }
  end

  def descriptive_submitted?(resource_key)
    params[resource_key].respond_to?(:key?) && params[resource_key].key?(:title)
  end

  # curated_subjects satisfies the keyword requirement and must: authority
  # subjects are kept out of the Keywords box on purpose, so without it a curator
  # fixing a title on such a record has to invent a redundant keyword to save.
  def descriptive_valid?(descriptive, keywords: false, curated_subjects: false)
    return false if descriptive[:title].blank?
    return false if keywords && Array(descriptive[:keywords]).empty? && !curated_subjects

    true
  end

  # Kept OUT of descriptive_params: that hash is splatted straight into
  # save_descriptive! as the MODS payload, and this is not a MODS field.
  def curated_subjects_posted?(resource_key)
    ActiveModel::Type::Boolean.new.cast(params.dig(resource_key, :curated_subjects)).present?
  end

  # Must run BEFORE the mint: MODSMerge leaves a blank title untouched, so a
  # missing title otherwise yields a silently untitled Atlas resource.
  def title_missing?(permitted)
    return false if permitted['title'].present?

    flash[:alert] = 'Please provide a title.'
    true
  end

  def clean_keywords(raw)
    Array(raw).map { |k| k.to_s.strip }.reject(&:empty?).uniq
  end

  def load_descriptive!(klass)
    @descriptive = Metadata::MODSFields.call(xml: resource_mods(klass))
  end

  # The raw, structure-safe update path, and it must stay that way: it preserves
  # curated nodes and skips a needless OCFL MODS version on a no-op. Keep the
  # with_stale_retry too — right after a deposit the async ingest jobs are
  # writing the same Work, so this read→merge→write can lose the lock race.
  def save_descriptive!(klass, id, title:, description:, keywords: nil)
    with_stale_retry do
      xml = AtlasRb.const_get(klass).mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, title: title, abstract: description, keywords: keywords)
      break if Metadata::MODSMerge.unchanged?(xml, merged)

      AtlasRb.const_get(klass).update(id, write_tmp_xml(merged))
    end
  end

  # Guard, mint, title — in that order, and the title before anything else the
  # caller does: either Atlas call can fail, and this order leaves a titled
  # resource holding its minted ACL (correctable on the Permissions tab) rather
  # than a correctly-restricted resource with no title. See docs/deposit.md.
  #
  # @return [AtlasRb::Mash, nil] nil when the title was missing; the flash is
  #   already set, so the caller only sends the reader back to the form.
  def mint_titled!(klass, resource_key)
    permitted = params.expect(resource_key => [:title, :description]).to_h
    return nil if title_missing?(permitted)

    resource = AtlasRb.const_get(klass).create(@destination_id)
    save_descriptive!(klass, resource.id, title: permitted['title'], description: permitted['description'])
    resource
  end

  def apply_descriptive(klass, id, resource_key, keywords, show_path)
    descriptive = descriptive_params(resource_key, keywords: keywords)
    unless descriptive_valid?(descriptive, keywords:         keywords,
                                           curated_subjects: curated_subjects_posted?(resource_key))
      flash[:alert] = keywords ? 'Please provide a title and at least one keyword.' : 'Please provide a title.'
      return redirect_back_or_to(public_send("edit_#{klass.downcase}_path", id))
    end

    save_descriptive!(klass, id, **descriptive)
    redirect_to show_path
  end
end
