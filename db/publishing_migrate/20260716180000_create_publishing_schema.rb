# frozen_string_literal: true

require_relative "../migration_support/publishing_schema"

class CreatePublishingSchema < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      PublishingSchema.create_schema(self)
    end
  end
end
