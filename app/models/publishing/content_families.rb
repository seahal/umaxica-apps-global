# frozen_string_literal: true

module Publishing
  # Explicit roster of the twelve physical content cells. Request paths must
  # still name a concrete ENTRY_CLASS; this list is for seeds, architecture
  # tests, and fixtures that already know the cell.
  module ContentFamilies
    ENTRY_CLASSES = [
      Publishing::Info::App::Entry,
      Publishing::Info::Com::Entry,
      Publishing::Info::Org::Entry,
      Publishing::Docs::App::Entry,
      Publishing::Docs::Com::Entry,
      Publishing::Docs::Org::Entry,
      Publishing::News::App::Entry,
      Publishing::News::Com::Entry,
      Publishing::News::Org::Entry,
      Publishing::Help::App::Entry,
      Publishing::Help::Com::Entry,
      Publishing::Help::Org::Entry,
    ].freeze

    def self.entry_class(surface:, audience:)
      ENTRY_CLASSES.find { |klass| klass::SURFACE == surface.to_s && klass::AUDIENCE == audience.to_s }
    end
  end
end
