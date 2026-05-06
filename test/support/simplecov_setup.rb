# typed: false
# frozen_string_literal: true

if ENV["RAILS_ENV"] == "test" && ENV["COVERAGE"] == "true"
  require "simplecov"
  require "simplecov-lcov"

  SimpleCov::Formatter::LcovFormatter.config do |c|
    c.report_with_single_file = true
    c.single_report_path = "coverage/rails/lcov.info"
  end

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter,
    ],
  )

  SimpleCov.start("rails") do
    coverage_dir "coverage/rails"
    enable_coverage :branch

    # Coverage thresholds: fail build if line < 86%, branch < 63%
    minimum_coverage line: 86, branch: 63

    # Do not allow coverage drops (fail if decreased from previous run)
    # refuse_coverage_drop :line, :branch

    filters.clear
    add_filter ".bundle/"
    add_filter "vendor/"
    add_filter "test/"
    add_filter "config/"
    add_filter "db/"
    add_filter "bin/"
    add_filter "docs/"
    add_filter "plans/"
    add_filter "adr/"
    add_filter "log/"
    add_filter "docker/"
    add_filter "dependency/"
    add_filter "public/"
    add_filter "node_modules/"
    add_filter "app/views/"
  end
end
