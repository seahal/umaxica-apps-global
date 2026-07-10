# typed: false
# frozen_string_literal: true

module GroupManagement
  class Create < ApplicationService
    def initialize(account_surface:, account_public_id:, name:, description: nil)
      super()
      @account_surface = account_surface.to_s
      @account_public_id = account_public_id.to_s
      @name = name
      @description = description
    end

    def call
      AvatarGroup.create!(
        account_surface: account_surface,
        account_public_id: account_public_id,
        name: name,
        description: description,
        state: "active",
      )
    end

    private

    attr_reader :account_surface, :account_public_id, :name, :description
  end
end
