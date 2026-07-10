# typed: false
# frozen_string_literal: true

module Cms
  module ImmutableRecord
    extend ActiveSupport::Concern

    def self.readonly_record?(record) = record.persisted?

    def readonly?
      Cms::ImmutableRecord.readonly_record?(self) || super
    end

    included do
      before_destroy { throw(:abort) if persisted? }
    end
  end
end
