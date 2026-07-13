# frozen_string_literal: true

require_relative "../migration_support/cms_schema"

class CreateAppCmsSchema < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      %i(docs news info help).each { |family| CmsSchema.create_family(self, surface: :app, family:) }
    end
  end
end
