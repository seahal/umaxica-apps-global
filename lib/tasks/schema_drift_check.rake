# typed: false
# frozen_string_literal: true

namespace :db do
  desc "Verify committed db/*_schema.rb files match what migrations produce from a clean DB"
  task verify_no_schema_drift: :environment do
    abort "refuse to run in production" if Rails.env.production?

    sh "RAILS_ENV=test bin/rails db:drop db:create db:migrate"

    drifted = `git status --porcelain db/`.lines
      .map { |l| l.strip.split(/\s+/, 2).last }
      .select { |path| path&.end_with?("_schema.rb") }

    if drifted.any?
      warn "schema drift detected:"
      drifted.each { |path| warn "  #{path}" }
      warn ""
      warn "The schema files committed to git do not match what running"
      warn "migrations from a clean DB produces. To fix locally:"
      warn ""
      warn "  bin/db-reset-all test"
      warn "  git add db/*_schema.rb"
      warn ""
      abort
    end

    puts "no schema drift."
  end
end
