# frozen_string_literal: true

# The WebVTT Blobs an audio or video Work carries, one per language, each served
# as a player <track>. A caption is discriminated by MIME TYPE, never by role:
# Atlas gives every content Blob the role `original_file`, video original
# included. See docs/metadata-text.md.
class CaptionTrack
  MIME = 'text/vtt'
  EXTENSION = '.vtt'

  # What a caption with no recorded language is taken to be. Every caption
  # stored before Atlas kept a language was offered to players as English.
  LANGUAGE = 'en'
  LABEL = 'English'

  # The select's choices: [BCP 47 tag, the English name, the language's own
  # name]. The own name is the track label, because that is what a reader of
  # the language looks for in the player's captions menu.
  LANGUAGES = [
    %w[en English English],
    %w[es Spanish Español],
    %w[fr French Français],
    %w[de German Deutsch],
    %w[it Italian Italiano],
    %w[pt Portuguese Português],
    %w[zh Chinese 中文],
    %w[ja Japanese 日本語],
    %w[ko Korean 한국어],
    %w[ar Arabic العربية],
    %w[hi Hindi हिन्दी],
    %w[ru Russian Русский]
  ].freeze
  OTHER = 'other'

  # Atlas checks the same shape and refuses a malformed tag with 422, but only
  # after the upload is staged and the job queued. Checking here refuses it at
  # the form, where the depositor can still correct it.
  TAG_FORMAT = /\A[a-z]{2,3}(-[a-z0-9]{2,8})*\z/i
  LABEL_LIMIT = 64

  # Atlas labels every text Blob "Text Document"; a caption file is named for
  # what it is instead, and by its language, so two captions can be told apart.
  DOWNLOAD_LABEL = 'captions'

  REFUSED = 'Caption files must be in WebVTT (.vtt) format. Contact repository staff for help converting ' \
            'caption files to WebVTT.'
  REFUSED_LANGUAGE = "Choose the caption file's language. For Other, give a language tag such as \"es-MX\" " \
                     "and a label of at most #{LABEL_LIMIT} characters.".freeze

  # The Work's caption Blobs, English first and then by label, so the first is
  # the track a player turns on by default. The `uri` test excludes Delegates —
  # the image tiers — which are not content.
  def self.all(files)
    Array(files).select { |file| caption?(file) }
                .sort_by { |file| [language(file) == LANGUAGE ? 0 : 1, label(file)] }
  end

  # The caption in this language, or nil.
  def self.for_language(files, language)
    all(files).find { |file| language(file).casecmp?(language.to_s) }
  end

  # "Español (México) captions": the label leads, because a label can carry its
  # own brackets and "Captions (Español (México))" would nest them.
  def self.download_label(file)
    "#{label(file)} #{DOWNLOAD_LABEL}"
  end

  def self.caption?(file)
    file[:uri].blank? && file.mime_type.to_s == MIME
  end

  def self.language(file)
    file[:language].presence || LANGUAGE
  end

  def self.label(file)
    file[:track_label].presence || LANGUAGES.find { |tag, _| tag.casecmp?(language(file)) }&.last || language(file)
  end

  # A submitted choice as [tag, label], or nil when it is not one this form
  # offers or the Other fields do not describe a language.
  def self.choice(language, other_tag: nil, other_label: nil)
    return LANGUAGES.find { |tag, _| tag == language }&.values_at(0, 2) unless language == OTHER

    tag = other_tag.to_s.strip
    label = other_label.to_s.strip
    [tag, label] if tag.match?(TAG_FORMAT) && label.present? && label.length <= LABEL_LIMIT
  end

  # Audio or video. Its own predicate rather than StreamingOnly.applicable?,
  # which tests the same thing today for an unrelated reason — not one rule.
  def self.applicable?(files)
    Array(files).any? { |file| file[:uri].blank? && file.mime_type.to_s.start_with?('video/', 'audio/') }
  end

  # The extension, never sniffed content: WebVTT is plain text, so a sniffer
  # reports text/plain for a perfectly good caption file.
  def self.accepted?(filename)
    File.extname(filename.to_s).downcase == EXTENSION
  end
end
