# typed: false
# frozen_string_literal: true

require "open3"

namespace :db do
  desc "Dump schemas and fail when committed schema dump files drift"
  task verify_no_schema_drift: :environment do
    schema_files =
      ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).filter_map do |db_config|
        dump = db_config.schema_dump
        next if dump == false

        path = dump.presence || ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(db_config)
        path = Rails.root.join("db", path) unless Pathname.new(path.to_s).absolute?
        path.relative_path_from(Rails.root).to_s
      end
    schema_files.uniq!
    schema_files.sort!

    if schema_files.empty?
      puts "No schema dump files are configured for #{Rails.env}."
      next
    end

    Rake::Task["db:schema:dump"].invoke

    stdout, stderr, status = Open3.capture3(
      "git",
      "diff",
      "--name-only",
      "--",
      *schema_files,
      chdir: Rails.root.to_s,
    )
    abort(stderr.presence || I18n.t("db_verify_no_schema_drift.unable_to_inspect")) unless status.success?

    drifted = stdout.lines.map(&:strip)
    drifted.reject!(&:empty?)
    if drifted.any?
      abort(
        [
          "Schema drift detected in committed schema dump files:",
          *drifted.map { |file| "  - #{file}" },
          I18n.t("db_verify_no_schema_drift.run_reset_workflow"),
        ].join("\n"),
      )
    end

    puts "No schema drift detected in #{schema_files.size} schema dump file(s)."
  end
end
