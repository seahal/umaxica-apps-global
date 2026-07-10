# typed: false
# frozen_string_literal: true

module GroupManagement
  class Archive < ApplicationService
    def initialize(group:)
      super()
      @group = group
    end

    def call
      return group if group.archived?

      group.update!(state: "archived", archived_at: Time.current)
      group
    end

    private

    attr_reader :group
  end
end
