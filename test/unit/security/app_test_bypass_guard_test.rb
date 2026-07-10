# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AppTestBypassGuardTest < Minitest::Test
  FORBIDDEN_PATTERNS = [
    /X-TEST-CURRENT/,
    /X-TEST-BULLETIN/,
    /TEST_CURRENT/,
    /TEST_BULLETIN/,
    /TEST_SESSION_PUBLIC_ID/,
    /mock_auth_from_test_mode/,
    /maybe_inject_test_bulletin/,
    /apply_test_mode_state_bypass/,
    /allow_test_mode_state_bypass/,
    /test_user_from_header/,
    /Thread\.current\[:.*test/,
    /CloudflareTurnstile\.test_/,
    /Turnstile\.test_response/,
    /JitSecurityTurnstileVerifier\.test_/,
    /data-testid/,
    /testid:/,
  ].freeze
  FORBIDDEN_PATTERN = Regexp.union(FORBIDDEN_PATTERNS)

  def test_app_and_lib_code_do_not_contain_test_only_auth_or_verification_bypass_hooks
    offenders = []

    paths = Rails.root.glob("{app,lib}/**/*").select { |path| File.file?(path) }
    paths.each do |path|
      relative_path = path.relative_path_from(Rails.root).to_s
      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

      content.each_line.with_index(1) do |line, line_number|
        offenders << "#{relative_path}:#{line_number}: #{line.strip}" if line.match?(FORBIDDEN_PATTERN)
      end
    end

    assert_empty offenders, offenders.join("\n")
  end
end
