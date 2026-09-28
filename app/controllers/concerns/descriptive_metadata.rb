# frozen_string_literal: true

# The simple-form descriptive fields (title, abstract, keywords) for the
# Metadata tab. Every edit MERGES into the resource's existing MODS, never
# replaces it, so curated nodes the form does not own survive. See
# docs/deposit.md.
module DescriptiveMetadata
  extend ActiveSupport::Concern
  include AtlasWrite

  def descriptive_params(keywords: false)
    raw = params.require(resource_key).permit(:title, :description, keywords: [])
    {
      title:       raw[:title],
      description: raw[:description],
      keywords:    keywords ? clean_keywords(raw[:keywords]) : nil
    }
  end

  def descriptive_submitted?
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

  # Read from the stored record, never from the form: a posted flag would let
  # any editor save a Work with no subjects at all by claiming curated ones.
  def curated_subjects_stored?
    Metadata::MODSFields.call(xml: resource_mods)[:curated_subjects]
  end

  # Must run BEFORE the mint: MODSMerge leaves a blank title untouched, so a
  # missing title otherwise yields a silently untitled Atlas resource.
  def title_missing?(permitted)
    return false if permitted['title'].present?

    flash[:alert] = missing_title_alert
    true
  end

  def missing_title_alert
    "Please give your #{resource_key.to_s.humanize(capitalize: false)} a title."
  end

  def clean_keywords(raw)
    Array(raw).map { |k| k.to_s.strip }.reject(&:empty?).uniq
  end

  def load_descriptive!
    @descriptive = Metadata::MODSFields.call(xml: resource_mods)
  end

  # The raw, structure-safe update path, and it must stay that way: it preserves
  # curated nodes and skips a needless OCFL MODS version on a no-op.
  #
  # `advanced` folds the Advanced field set into the SAME merge, for a form that
  # carries both — the deposit page. Two sequential saves would mint two OCFL
  # MODS versions and two audit rows for one submit.
  def save_descriptive!(id, title:, description:, keywords: nil, advanced: nil, origin: 'metadata_form')
    merge_mods!(id, origin: origin,
                    title: title, abstract: description, keywords: keywords,
                    **(advanced || {}))
  end

  # Guard, mint, title — in that order, and the title before anything else the
  # caller does: either Atlas call can fail, and this order leaves a titled
  # resource holding its minted ACL (correctable on the Permissions tab) rather
  # than a correctly-restricted resource with no title. See docs/deposit.md.
  #
  # @return [AtlasRb::Mash, nil] nil when the title was missing; the flash is
  #   already set, so the caller only sends the reader back to the form.
  def mint_titled!
    permitted = params.expect(resource_key => [:title, :description]).to_h
    return nil if title_missing?(permitted)

    resource = atlas_class.create(@destination_id)
    save_descriptive!(resource.id, title: permitted['title'], description: permitted['description'])
    resource
  end

  def apply_descriptive(id, advanced: nil)
    keywords = DescriptivePolicy.keywords_required?(atlas_class)
    descriptive = descriptive_params(keywords: keywords)
    curated = keywords && Array(descriptive[:keywords]).empty? && curated_subjects_stored?
    unless descriptive_valid?(descriptive, keywords:, curated_subjects: curated)
      flash[:alert] = keywords ? 'Please provide a title and at least one keyword.' : missing_title_alert
      return redirect_back_or_to(edit_path(id))
    end

    save_descriptive!(id, **descriptive, advanced: advanced)
    redirect_to show_path(id)
  end
end
