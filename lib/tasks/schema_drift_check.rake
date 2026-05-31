# typed: false
# frozen_string_literal: true

namespace :db do
  desc "Verify committed db/*_structure.sql files match what migrations produce from a clean DB"
  task verify_no_schema_drift: :environment do
    abort "refuse to run in production" if Rails.env.production?

    sh "RAILS_ENV=test bin/rails db:drop db:create db:migrate db:schema:dump"

    paths =
      `git status --porcelain db/`.lines
        .map { |l| l.strip.split(/\s+/, 2).last }
    paths.select! { |path| path&.end_with?("_structure.sql") }
    drifted = paths

    if drifted.any?
      warn "schema drift detected:"
      drifted.each { |path| warn "  #{path}" }
      warn ""
      warn "The schema files committed to git do not match what running"
      warn "migrations from a clean DB produces. To fix locally:"
      warn ""
      warn "  RAILS_ENV=test bin/rails db:migrate:reset"
      warn "  git add db/*_structure.sql"
      warn ""
      abort
    end

    puts "no schema drift."
  end
end
