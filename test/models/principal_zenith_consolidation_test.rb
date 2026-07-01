# typed: false
# frozen_string_literal: true

require "test_helper"

class PrincipalZenithConsolidationTest < ActiveSupport::TestCase
  SURFACE_CONFIG = {
    app: {
      principal: "app_principal",
      zenith: "app_zenith",
      principal_path: "db/app_principal_reserved_migrate",
      combined_paths: %w(db/app_principals_migrate db/app_zenith_migrate),
    },
    org: {
      principal: "org_principal",
      zenith: "org_zenith",
      principal_path: "db/org_principal_reserved_migrate",
      combined_paths: %w(db/org_principals_migrate db/org_zenith_migrate),
    },
    com: {
      principal: "com_principal",
      zenith: "com_zenith",
      principal_path: "db/com_principal_reserved_migrate",
      combined_paths: %w(db/com_principals_migrate db/com_zenith_migrate),
    },
  }.freeze

  test "principal configs use reserved empty migration paths" do
    SURFACE_CONFIG.each_value do |config|
      assert_equal config.fetch(:principal_path),
                   database_config(config.fetch(:principal)).fetch(:migrations_paths)
      assert_equal config.fetch(:principal_path),
                   database_config("#{config.fetch(:principal)}_replica").fetch(:migrations_paths)
    end
  end

  test "zenith configs include principal and zenith migration paths" do
    SURFACE_CONFIG.each_value do |config|
      assert_equal config.fetch(:combined_paths),
                   database_config(config.fetch(:zenith)).fetch(:migrations_paths)
      assert_equal config.fetch(:combined_paths),
                   database_config("#{config.fetch(:zenith)}_replica").fetch(:migrations_paths)
    end
  end

  test "combined migration paths do not have duplicate versions, names, or class names" do
    SURFACE_CONFIG.each_value do |config|
      migration_files =
        config.fetch(:combined_paths).flat_map do |path|
          Rails.root.glob("#{path}/*.rb")
        end

      versions = migration_files.map { |path| path.basename.to_s.split("_", 2).first }

      assert_equal versions.uniq.sort, versions.sort

      names = migration_files.map { |path| path.basename.to_s.delete_suffix(".rb").split("_", 2).last }

      assert_equal names.uniq.sort, names.sort

      class_names =
        migration_files.filter_map do |path|
          File.read(path).match(/^class\s+([A-Z]\w*)\s*</)&.[](1)
        end

      assert_equal class_names.uniq.sort, class_names.sort
    end
  end

  private

  def database_config(name)
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name, include_hidden: true)
      .configuration_hash
  end
end
