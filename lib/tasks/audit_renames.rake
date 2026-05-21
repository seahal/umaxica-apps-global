# typed: false
# frozen_string_literal: true

namespace :db do
  desc "Verify no migration reintroduces the silent rename_table_if_present pattern"
  task :audit_renames do
    forbidden_patterns = {
      "rename_table_if_present (silent skip helper)" =>
        /\brename_table_if_present\b/,
    }

    hits = []
    Dir.glob("db/*_migrate/*.rb").sort.each do |path|
      File.foreach(path).with_index(1) do |line, lineno|
        forbidden_patterns.each do |label, regex|
          hits << "#{path}:#{lineno}  #{label}" if line.match?(regex)
        end
      end
    end

    if hits.any?
      warn "Found #{hits.size} silent-rename pattern(s) — use rename_table_strict instead:"
      hits.each { |h| warn "  #{h}" }
      warn ""
      warn "See AGENTS.md \"Table renames\" and docs/operations/db-workflow.md."
      exit 1
    else
      puts "no silent rename patterns found."
    end
  end
end
