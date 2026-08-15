# frozen_string_literal: true

# The simple-form descriptive fields (title, abstract, keywords) for the
# Metadata tab: parse them out of the resource's raw MODS to pre-fill, validate
# what comes back, and merge the edits into the existing MODS rather than
# replacing it — so every curated node the form does not own survives.
module DescriptiveMetadata
  extend ActiveSupport::Concern
  include AtlasWrite

  # Descriptive (MODS) fields the simple Metadata form owns; symbol-keyed for
  # MODSMerge. `keywords: false` (containers) leaves keyword subjects untouched.
  def descriptive_params(resource_key, keywords: false)
    raw = params.require(resource_key).permit(:title, :description, keywords: [])
    {
      title:       raw[:title],
      description: raw[:description],
      keywords:    keywords ? clean_keywords(raw[:keywords]) : nil
    }
  end

  # True when the request carried the descriptive (Metadata-tab) form rather than
  # the permissions form — both POST to #update with disjoint fields.
  def descriptive_submitted?(resource_key)
    params[resource_key].respond_to?(:key?) && params[resource_key].key?(:title)
  end

  # `keywords: true` means "this resource must carry at least one subject", and the
  # Keywords box is how a depositor supplies one. A record whose subjects are all
  # authority-controlled already satisfies that, and those subjects are curated:
  # MODSFields keeps them out of the box on purpose and MODSMerge never writes over
  # them. So the form posts `curated_subjects` and it counts here — otherwise a
  # curator fixing a title on such a record must invent a redundant keyword to save.
  def descriptive_valid?(descriptive, keywords: false, curated_subjects: false)
    return false if descriptive[:title].blank?
    return false if keywords && Array(descriptive[:keywords]).empty? && !curated_subjects

    true
  end

  # Cast the flag the descriptive form posts alongside the MODS fields. Kept out of
  # descriptive_params because that hash is splatted straight into save_descriptive!
  # as the MODS payload, and this is not a MODS field.
  #
  # Trusting a form value is fine here: the guard is a curation prompt, not a
  # security boundary — Atlas is that — so the worst a tampered value buys is a Work
  # saved with no subjects, which the API permits anyway.
  def curated_subjects_posted?(resource_key)
    ActiveModel::Type::Boolean.new.cast(params.dig(resource_key, :curated_subjects)).present?
  end

  # Create-path title guard (containers): flashes and returns true when the
  # permitted params carry no title, so the controller can redirect back before
  # minting an Atlas resource — a blank title otherwise yields a silently
  # untitled object (MODSMerge leaves a blank title untouched).
  def title_missing?(permitted)
    return false if permitted['title'].present?

    flash[:alert] = 'Please provide a title.'
    true
  end

  def clean_keywords(raw)
    Array(raw).map { |k| k.to_s.strip }.reject(&:empty?).uniq
  end

  # Parse the simple-form descriptive fields out of the resource's raw MODS so
  # the edit form pre-fills with the BARE title (+ read-only structured parts),
  # the abstract, and the free-text keywords — exactly what #update merges back.
  def load_descriptive!(klass)
    @descriptive = Metadata::MODSFields.call(xml: AtlasRb.const_get(klass).mods(params[:id], 'xml'))
  end

  # Merge the descriptive fields into the existing MODS and write via the raw,
  # structure-safe update path — preserving every curated node the form does not
  # own, and skipping the write (and a needless OCFL MODS version) on a no-op.
  # Wrapped in with_stale_retry: right after a deposit the async ingest/derivative
  # jobs are still finalizing the same Work, so this read→merge→write can lose an
  # optimistic-lock race; re-reading picks up the current MODS + token.
  def save_descriptive!(klass, id, title:, description:, keywords: nil)
    with_stale_retry do
      xml = AtlasRb.const_get(klass).mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, title: title, abstract: description, keywords: keywords)
      break if Metadata::MODSMerge.unchanged?(xml, merged)

      AtlasRb.const_get(klass).update(id, write_tmp_xml(merged))
    end
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
