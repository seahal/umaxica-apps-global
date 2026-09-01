# typed: false
# frozen_string_literal: true

require "test_helper"

# Static regression guards for the WebAuthn security invariants documented in
# docs/security/webauthn-security-invariants.md. Each rule below encodes a
# previously shipped defect; a match means the defect pattern was reintroduced.
class WebauthnInvariantsTest < ActiveSupport::TestCase
  APP_ROOT = Rails.root.join("app")

  WEBAUTHN_SOURCE_GLOBS = %w(
    app/controllers/**/*.rb
    app/services/**/*.rb
    app/values/**/*.rb
    app/resolvers/**/*.rb
    app/models/**/*.rb
    config/initializers/webauthn.rb
  ).freeze

  test "no user_verification preferred or discouraged anywhere in application code" do
    offenders = scan(/user_verification.{0,20}(preferred|discouraged)/i)

    assert_empty offenders,
                 "AAL2-aligned paths require userVerification=required; found weakened UV policy " \
                 "in:\n#{offenders.join("\n")}"
  end

  test "user_verification strings appear only in the UvPolicy registry" do
    offenders = []

    each_source_file do |path, source|
      next if path == "app/values/webauthn/uv_policy.rb"

      source.each_line.with_index(1) do |line, number|
        next unless line.match?(/user_verification.{0,20}["'](required|preferred|discouraged)["']/i)
        next if line.strip.start_with?("#")

        offenders << "#{path}:#{number}: #{line.strip}"
      end
    end

    assert_empty offenders,
                 "UV policy values must come from Webauthn::UvPolicy, never raw strings at call " \
                 "sites:\n#{offenders.join("\n")}"
  end

  test "assertion and registration verifiers resolve UV through UvPolicy" do
    %w(app/services/webauthn/registration_verifier.rb app/services/webauthn/assertion_verifier.rb).each do |path|
      source = Rails.root.join(path).read

      assert_includes source, "UvPolicy.for(",
                      "#{path} must resolve its user-verification requirement via Webauthn::UvPolicy"
    end
  end

  test "no request.host or request.base_url fallback in WebAuthn code" do
    offenders = scan(/request\.(host|base_url)/, only_webauthn_files: true)

    assert_empty offenders,
                 "WebAuthn RP ID/origin must come from per-surface configuration, never the " \
                 "request:\n#{offenders.join("\n")}"
  end

  test "no shared WEBAUTHN_RP_ID or WEBAUTHN_ORIGIN environment keys" do
    offenders = scan(/WEBAUTHN_(RP_ID|ORIGIN|RP_MAP)\b/)

    assert_empty offenders,
                 "Surface-shared WebAuthn env keys are forbidden; use WEBAUTHN_<APP|COM|ORG>_* " \
                 "only:\n#{offenders.join("\n")}"
  end

  test "no controller-class-name regex surface guessing" do
    offenders = scan(/\\ASign::(App|Com|Org)::/, only_webauthn_files: true)

    assert_empty offenders,
                 "Surface resolution must be declared explicitly, not inferred from class " \
                 "names:\n#{offenders.join("\n")}"
  end

  test "no global WebAuthn configuration mutation outside gem defaults" do
    offenders = scan(/WebAuthn\.configuration\b|WebAuthn\.configure\b/)

    assert_empty offenders,
                 "Per-request ceremonies must use explicit WebAuthn::RelyingParty instances:\n#{offenders.join("\n")}"
  end

  test "every from_get and from_create passes an explicit relying party" do
    offenders = []

    each_source_file do |path, source|
      source.scan(/WebAuthn::Credential\.from_(?:get|create)\((?:[^()]|\([^()]*\))*\)/m) do |call|
        offenders << "#{path}: #{call.lines.first.strip}" unless call.include?("relying_party:")
      end
    end

    assert_empty offenders,
                 "WebAuthn::Credential.from_get/from_create must receive relying_party::\n#{offenders.join("\n")}"
  end

  test "no host-only origin comparison in WebAuthn code" do
    offenders = scan(/scheme\s*==.*&&.*host\s*==(?!.*port)/, only_webauthn_files: true)

    assert_empty offenders,
                 "Origin comparison must include scheme, host, and effective port:\n#{offenders.join("\n")}"
  end

  private

  def each_source_file
    WEBAUTHN_SOURCE_GLOBS.each do |glob|
      Rails.root.glob(glob).each do |path|
        yield path.relative_path_from(Rails.root).to_s, File.read(path)
      end
    end
  end

  def scan(pattern, only_webauthn_files: false)
    offenders = []

    each_source_file do |path, source|
      next if only_webauthn_files && !source.match?(/webauthn/i) && path.exclude?("webauthn")

      source.each_line.with_index(1) do |line, number|
        next unless line.match?(pattern)
        next if line.strip.start_with?("#")

        offenders << "#{path}:#{number}: #{line.strip}"
      end
    end

    offenders
  end
end
