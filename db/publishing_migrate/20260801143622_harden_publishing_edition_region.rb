# frozen_string_literal: true

require_relative "../migration_support/publishing_schema"

# region_code shipped as a free-form nullable label. Info is global and carries
# no region; docs, news, and help are regional and must carry one. The regional
# surfaces are listed explicitly rather than written as `surface <> 'info'` so
# that an unknown future surface cannot become regional by default.
class HardenPublishingEditionRegion < ActiveRecord::Migration[8.2]
  REGIONAL_SURFACES = %w(docs news help).freeze

  def up
    safety_assured do
      add_check_constraint(:publishing_editions, region_constraint, name: "chk_publishing_editions_region")
    end
  end

  def down
    remove_check_constraint(:publishing_editions, region_constraint, name: "chk_publishing_editions_region")
  end

  private

  def region_constraint
    regional = REGIONAL_SURFACES.map { |surface| "'#{surface}'" }.join(",")

    "(surface = 'info' AND region_code IS NULL) OR " \
      "(surface IN (#{regional}) AND region_code IS NOT NULL AND region_code ~ '^[a-z]{2}$')"
  end
end
