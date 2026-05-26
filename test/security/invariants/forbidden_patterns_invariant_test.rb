# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    class ForbiddenPatternsInvariantTest < ActiveSupport::TestCase
      fixtures_none!

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      FORBIDDEN_PATTERNS = {
        "mass-assignment permit!" => /\bpermit!\b/,
        "access policy bypass" => /skip_before_action\s+:enforce_access_policy!/,
        "csrf bypass" => /\bskip_forgery_protection\b/,
        "csrf null_session" => /\bprotect_from_forgery\b.*\bwith:\s*:null_session\b|\bwith:\s*:null_session\b/,
        "unsafe HTML html_safe" => /\bhtml_safe\b/,
        "unsafe HTML raw(...)" => /\braw\s*\(/,
        "thread-local request state" => /\bThread\.current\b/,
        "ignored rescue nil" => /rescue\s+nil\b/,
        "cross-host redirect escape hatch" => /\ballow_other_host:\s*true\b/,
      }.freeze

      SECURITY_LOGGER_PATH_PATTERN =
        %r{\A(?:app|lib)/(?:controllers/concerns/(?:authentication|authorization_audit|sign|oidc)|
                          controllers/sign/|
                          services/(?:chronicle|jit/security|social_auth)|
                          subscribers/jwt_anomaly_subscriber|
                          jit/security)}x

      # Allowlist entries document existing reviewed exceptions. They are not
      # blanket permission for new uses: the line snippet must still match.
      # Responsibility: owners of the named component must migrate to
      # Rails.logger with LogEvent.format or a sanitized audit sink before
      # removing the exception.
      ALLOWLIST = [
        {
          pattern: "access policy bypass",
          path: "app/controllers/concerns/authentication/base.rb",
          line: /skip_before_action :enforce_access_policy! is prohibited/,
          reason: "Policy guard raises on attempts to skip enforce_access_policy!.",
        },
        {
          pattern: "cross-host redirect escape hatch",
          path: "app/controllers/concerns/common/redirect.rb",
          line: /redirect_to\(result\.value, allow_other_host: true/,
          reason: "Only the xt redirect facade may enable cross-host redirects after resolver validation.",
        },
      ].freeze

      LOGGER_ALLOWLIST = [].freeze

      test "allowlist entries have explicit reasons" do
        missing_reasons =
          (ALLOWLIST + LOGGER_ALLOWLIST).filter_map do |entry|
            "#{entry[:path]} #{entry[:pattern]}" if entry.fetch(:reason).blank?
          end

        assert_empty missing_reasons, "Forbidden-pattern allowlist entries require reasons"
      end

      test "production code does not introduce forbidden security patterns" do
        offenders =
          production_code_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              pattern_name = FORBIDDEN_PATTERNS.find { |_name, pattern| line.match?(pattern) }&.first
              next unless pattern_name
              next if allowlisted?(ALLOWLIST, pattern_name, relative_path, line)

              "#{relative_path}:#{line_number}: #{pattern_name}: #{line.strip}"
            end
          end

        assert_empty offenders, "Forbidden security patterns found:\n#{offenders.join("\n")}"
      end

      test "authentication audit and security code uses structured logger error calls" do
        offenders =
          production_code_paths.filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next unless relative_path.match?(SECURITY_LOGGER_PATH_PATTERN)

            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
            lines = content.lines
            lines.each_with_index.filter_map do |line, index|
              next unless line.match?(/\bRails\.logger\.error\b/)
              next if lines[index, 4].join.include?("LogEvent.format(")
              next if allowlisted?(LOGGER_ALLOWLIST, nil, relative_path, line)

              line_number = index + 1
              "#{relative_path}:#{line_number}: direct Rails.logger.error: #{line.strip}"
            end
          end.flatten

        assert_empty offenders,
                     "Use Rails.logger.error(LogEvent.format(...)) or a sanitized audit sink instead:\n" \
                     "#{offenders.join("\n")}"
      end

      private

      def production_code_paths
        Rails.root.glob("{app,lib}/**/*").select do |path|
          File.file?(path) &&
            path.extname.in?(%w(.rb .erb .rake)) &&
            path.to_s.exclude?("/app/assets/builds/")
        end
      end

      def allowlisted?(entries, pattern_name, path, line)
        entries.any? do |entry|
          (pattern_name.nil? || entry[:pattern] == pattern_name) &&
            entry.fetch(:path) == path &&
            line.match?(entry.fetch(:line))
        end
      end
    end
  end
end
