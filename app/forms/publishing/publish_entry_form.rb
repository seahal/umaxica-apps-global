# typed: false
# frozen_string_literal: true

module Publishing
  # Input for publishing an entry.
  #
  # `effective_from` is optional: absent means "now", which is what the
  # Publish button sends. A value schedules the window instead, and the
  # operation ends the live window at that same instant, so a scheduled
  # publication is expressed as one field rather than a second workflow.
  #
  # The text is parsed here rather than by Active Record's type coercion
  # because a datetime Rails cannot parse coerces to `nil`, which would read
  # as "publish now" -- the operator would get an immediate publication they
  # did not ask for.
  #
  # ISO 8601 rather than `Time.zone.parse`, which reads a best effort out of
  # almost any string: "next tuesday-ish" parses, and the window would open at
  # a time nobody chose. The field the CMS renders is `datetime-local`, whose
  # value is already ISO 8601.
  class PublishEntryForm < ApplicationForm
    attribute :effective_from_text, :string

    attr_reader :effective_from

    validate :effective_from_must_be_parseable

    def message_hash
      errors.details.to_h { |attribute, list|
        [attribute, message_for(attribute, list.first.fetch(:error))]
      }
    end

    private

    def effective_from_must_be_parseable
      return if effective_from_text.blank?

      @effective_from = Time.zone.iso8601(effective_from_text)
    rescue ArgumentError
      errors.add(:effective_from, :malformed)
    end

    def message_for(attribute, error)
      if attribute == :effective_from && error == :malformed
        "must be a date and time"
      else
        error.to_s
      end
    end
  end
end
