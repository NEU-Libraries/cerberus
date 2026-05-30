# frozen_string_literal: true

module Iptc
  # Reads IPTC tags + image dimensions from a single JPEG in one
  # mini_exiftool invocation. Dimensions are returned alongside the tag
  # hash so the caller (IptcIngestJob) can do MODS construction and
  # derivative sizing from the same parse — no second exiftool call.
  #
  # Per-call instantiation only. Holding a MiniExiftool instance across
  # images retains its tag hash on the worker heap.
  class Extractor < ApplicationService
    class UnsupportedIptcType < StandardError
    end

    Result = Struct.new(:tags, :width, :height, keyword_init: true) do
      def longest_side
        [width.to_i, height.to_i].max
      end
    end

    def initialize(path:)
      @path = path
    end

    def call
      photo = MiniExiftool.new(@path, iptc_encoding: 'UTF8', exif_encoding: 'UTF8')
      Result.new(
        tags:   extract_tags(photo),
        width:  photo.imagewidth,
        height: photo.imageheight
      )
    end

    private

      def extract_tags(photo)
        photo.tags.each_with_object({}) do |tag, hash|
          val = photo[tag]
          next if blank_value?(val)

          hash[tag.to_sym] = coerce(val, tag)
        end
      end

      def blank_value?(val)
        val.nil? || (val.respond_to?(:empty?) && val.empty?)
      end

      def coerce(val, tag)
        case val
        when String, Time
          val
        when Numeric, TrueClass, FalseClass
          val.to_s
        when Array
          val.map(&:to_s).compact_blank
        else
          raise UnsupportedIptcType, "tag #{tag.inspect} contains #{val.class.name} data"
        end
      end
  end
end
