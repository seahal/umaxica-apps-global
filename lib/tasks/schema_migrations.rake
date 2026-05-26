# frozen_string_literal: true

namespace :db do
  desc "Mark configured database migration files as applied after schema load"
  task mark_schema_migrations: :environment do
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
      next if db_config.replica?

      ActiveRecord::Base.establish_connection(db_config)

      schema_migration = ActiveRecord::Base.connection_pool.schema_migration
      schema_migration.create_table
      migration_context = ActiveRecord::MigrationContext.new(db_config.migrations_paths, schema_migration)
      existing_versions = schema_migration.normalized_versions
      migration_context.migrations.each do |migration|
        version = migration.version.to_s
        schema_migration.create_version(version) unless existing_versions.include?(version)
      end
    end
  end
end
