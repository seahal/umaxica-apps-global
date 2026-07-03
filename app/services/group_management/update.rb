# typed: false
# frozen_string_literal: true

module GroupManagement
  class Update < ApplicationService
    def initialize(group:, attributes:)
      super()
      @group = group
      @attributes = attributes.to_h.slice(:name, :description)
    end

    def call
      raise ArgumentError, "group is archived" unless group.active?

      group.update!(attributes)
      group
    end

    private

    attr_reader :group, :attributes
  end
end
