# typed: false
# frozen_string_literal: true

require "test_helper"

# Enforces the controller inheritance contract:
#   Every peripheral controller must inherit directly from a surface ApplicationController
#   or BareController. Controller-to-controller inheritance is forbidden.
#
# When a violation is fixed, remove it from KNOWN_VIOLATIONS.
# If this test fails with a new violation, the PR must either fix the inheritance
# or add an explicit entry to KNOWN_VIOLATIONS with a documented reason.
class ControllerInheritanceInvariantTest < ActiveSupport::TestCase
  fixtures_none!

  # Pre-existing controller-to-controller inheritance violations that have not yet
  # been refactored. Each entry is the controller source path relative to Rails.root.
  # Do not add new entries without a documented reason.
  KNOWN_VIOLATIONS = [
    # Acme OAuth: JwksControllers delegate to a surface-local base that wraps JWKS
    # key serialization. Candidate for concern extraction.
    "app/controllers/acme/app/oauth/jwks_controller.rb",
    "app/controllers/acme/com/oauth/jwks_controller.rb",
    "app/controllers/acme/org/oauth/jwks_controller.rb",

    # Acme token refresh: RefreshesControllerBase provides shared token-refresh logic.
    "app/controllers/acme/com/edge/v0/token/refreshes_controller.rb",

    # Sign::App::Settings inheritance chains. These controllers share session-management
    # and passkey-registration behavior through local base classes. Candidate for concerns.
    "app/controllers/sign/app/settings/emails/redeliveries_controller.rb",
    "app/controllers/sign/app/settings/passkeys/options_controller.rb",
    "app/controllers/sign/app/settings/passkeys/verifications_controller.rb",
    "app/controllers/sign/app/settings/revocations_controller.rb",
    "app/controllers/sign/app/settings/revocations/alls_controller.rb",
    "app/controllers/sign/app/settings/revocations/others_controller.rb",

    # Sign::Com::Settings inheritance chains (parallel to app).
    "app/controllers/sign/com/settings/passkeys/options_controller.rb",
    "app/controllers/sign/com/settings/passkeys/verifications_controller.rb",
    "app/controllers/sign/com/settings/revocations_controller.rb",
    "app/controllers/sign/com/settings/revocations/alls_controller.rb",
    "app/controllers/sign/com/settings/revocations/others_controller.rb",

    # Sign::Org::Settings inheritance chains (parallel to app).
    "app/controllers/sign/org/settings/passkeys/options_controller.rb",
    "app/controllers/sign/org/settings/passkeys/verifications_controller.rb",
    "app/controllers/sign/org/settings/revocations_controller.rb",
    "app/controllers/sign/org/settings/revocations/alls_controller.rb",
    "app/controllers/sign/org/settings/revocations/others_controller.rb",

    # Sign::App::Sign::In::* inheriting from Sign::App::In::* base controllers.
    # The sign/sign/in/ layer is a routing namespace; in/ holds the behavior base.
    # These are the highest-priority follow-up to move to concerns.
    "app/controllers/sign/app/sign/in/challenge/passkeys_controller.rb",
    "app/controllers/sign/app/sign/in/challenge/totps_controller.rb",
    "app/controllers/sign/app/sign/in/challenges_controller.rb",
    "app/controllers/sign/app/sign/in/emails_controller.rb",
    "app/controllers/sign/app/sign/in/entrances_controller.rb",
    "app/controllers/sign/app/sign/in/guards_controller.rb",
    "app/controllers/sign/app/sign/in/passkey/options_controller.rb",
    "app/controllers/sign/app/sign/in/passkey/verifications_controller.rb",
    "app/controllers/sign/app/sign/in/passkeys_controller.rb",
    "app/controllers/sign/app/sign/in/secret_credentials_controller.rb",
    "app/controllers/sign/app/sign/in/session/cancellations_controller.rb",
    "app/controllers/sign/app/sign/in/sessions_controller.rb",

    # Sign::App::Sign::Up::* inheriting from Sign::App::Up::* base controllers.
    "app/controllers/sign/app/sign/up/check/apple/birthdates_controller.rb",
    "app/controllers/sign/app/sign/up/check/apple/cancellations_controller.rb",
    "app/controllers/sign/app/sign/up/check/apple/confirmations_controller.rb",
    "app/controllers/sign/app/sign/up/check/email/birthdates_controller.rb",
    "app/controllers/sign/app/sign/up/check/email/cancellations_controller.rb",
    "app/controllers/sign/app/sign/up/check/email/otps_controller.rb",
    "app/controllers/sign/app/sign/up/check/google/birthdates_controller.rb",
    "app/controllers/sign/app/sign/up/check/google/cancellations_controller.rb",
    "app/controllers/sign/app/sign/up/check/google/confirmations_controller.rb",
    "app/controllers/sign/app/sign/up/check/telephone/birthdates_controller.rb",
    "app/controllers/sign/app/sign/up/check/telephone/cancellations_controller.rb",
    "app/controllers/sign/app/sign/up/check/telephone/otps_controller.rb",
    "app/controllers/sign/app/sign/up/check/telephone/passcodes_controller.rb",
    "app/controllers/sign/app/sign/up/check/telephone/passkeys_controller.rb",
    "app/controllers/sign/app/sign/up/emails_controller.rb",
    "app/controllers/sign/app/sign/up/entrances_controller.rb",
    "app/controllers/sign/app/sign/up/guard/apples_controller.rb",
    "app/controllers/sign/app/sign/up/guard/emails_controller.rb",
    "app/controllers/sign/app/sign/up/guard/googles_controller.rb",
    "app/controllers/sign/app/sign/up/guard/telephones_controller.rb",
    "app/controllers/sign/app/sign/up/telephones_controller.rb",

    # Sign::App::Social::* inheriting from AuthenticationsController base.
    "app/controllers/sign/app/social/apple/connections_controller.rb",
    "app/controllers/sign/app/social/apple/disconnections_controller.rb",
    "app/controllers/sign/app/social/google/connections_controller.rb",
    "app/controllers/sign/app/social/google/disconnections_controller.rb",

    # Sign::App::Up::Check cross-family inheritance (google/confirmations inheriting apple base).
    # Note: otps and telephone/birthdates are also PERMITTED_LOCAL_BASES for the sign/sign/up
    # layer, so the detector skips them — they are not listed here to avoid false stale entries.
    "app/controllers/sign/app/up/check/google/confirmations_controller.rb",

    # Sign::App::Verification::RedeliveriesController < EmailsController.
    "app/controllers/sign/app/verification/redeliveries_controller.rb",

    # Sign::Com::Sign::In::* inheriting from Sign::Com::In::* base controllers.
    "app/controllers/sign/com/sign/in/challenge/passkeys_controller.rb",
    "app/controllers/sign/com/sign/in/challenges_controller.rb",
    "app/controllers/sign/com/sign/in/emails_controller.rb",
    "app/controllers/sign/com/sign/in/entrances_controller.rb",
    "app/controllers/sign/com/sign/in/guards_controller.rb",
    "app/controllers/sign/com/sign/in/passkey/options_controller.rb",
    "app/controllers/sign/com/sign/in/passkey/verifications_controller.rb",
    "app/controllers/sign/com/sign/in/passkeys_controller.rb",
    "app/controllers/sign/com/sign/in/secret_credentials_controller.rb",
    "app/controllers/sign/com/sign/in/session/cancellations_controller.rb",
    "app/controllers/sign/com/sign/in/sessions_controller.rb",

    # Sign::Com::Sign::Up::* inheriting from Sign::Com::Up::* base controllers.
    "app/controllers/sign/com/sign/up/check/email/birthdates_controller.rb",
    "app/controllers/sign/com/sign/up/check/email/cancellations_controller.rb",
    "app/controllers/sign/com/sign/up/check/email/otps_controller.rb",
    "app/controllers/sign/com/sign/up/check/telephone/birthdates_controller.rb",
    "app/controllers/sign/com/sign/up/check/telephone/cancellations_controller.rb",
    "app/controllers/sign/com/sign/up/check/telephone/otps_controller.rb",
    "app/controllers/sign/com/sign/up/check/telephone/passcodes_controller.rb",
    "app/controllers/sign/com/sign/up/check/telephone/passkeys_controller.rb",
    "app/controllers/sign/com/sign/up/emails_controller.rb",
    "app/controllers/sign/com/sign/up/entrances_controller.rb",
    "app/controllers/sign/com/sign/up/guard/emails_controller.rb",
    "app/controllers/sign/com/sign/up/guard/telephones_controller.rb",
    "app/controllers/sign/com/sign/up/telephones_controller.rb",

    # Sign::Com::Up::Check cross-family inheritance.
    # Note: com/up/check/email/otps and com/up/check/telephone/birthdates and otps are
    # also PERMITTED_LOCAL_BASES for the sign/sign/up layer, so not listed here.

    # Sign::Com::Verification::RedeliveriesController < EmailsController.
    "app/controllers/sign/com/verification/redeliveries_controller.rb",

    # Sign::Org::Sign::In::* inheriting from Sign::Org::In::* base controllers.
    "app/controllers/sign/org/sign/in/challenge/passkeys_controller.rb",
    "app/controllers/sign/org/sign/in/challenges_controller.rb",
    "app/controllers/sign/org/sign/in/entrances_controller.rb",
    "app/controllers/sign/org/sign/in/guards_controller.rb",
    "app/controllers/sign/org/sign/in/passkey/options_controller.rb",
    "app/controllers/sign/org/sign/in/passkey/verifications_controller.rb",
    "app/controllers/sign/org/sign/in/passkeys_controller.rb",
    "app/controllers/sign/org/sign/in/secret_credentials_controller.rb",
    "app/controllers/sign/org/sign/in/session/cancellations_controller.rb",
    "app/controllers/sign/org/sign/in/sessions_controller.rb",

    # Sign::Org::Sign::Up::* inheriting from Sign::Org::Up::* base controllers.
    "app/controllers/sign/org/sign/up/entrances_controller.rb",
    "app/controllers/sign/org/sign/up/invitations_controller.rb",
  ].to_set.freeze

  # Controllers that are themselves allowed to be base classes
  # (i.e., other controllers may inherit from these within KNOWN_VIOLATIONS above).
  # These must themselves inherit from ApplicationController or ActionController::Base.
  PERMITTED_LOCAL_BASES = %w(
    app/controllers/sign/app/in/challenges_controller.rb
    app/controllers/sign/app/in/emails_controller.rb
    app/controllers/sign/app/in/guards_controller.rb
    app/controllers/sign/app/in/passkeys_controller.rb
    app/controllers/sign/app/in/secret_credentials_controller.rb
    app/controllers/sign/app/in/sessions_controller.rb
    app/controllers/sign/app/settings/passkeys_controller.rb
    app/controllers/sign/app/settings/sessions_controller.rb
    app/controllers/sign/app/social/authentications_controller.rb
    app/controllers/sign/app/sign_ins_controller.rb
    app/controllers/sign/app/sign_ups_controller.rb
    app/controllers/sign/app/up/check/apple/birthdates_controller.rb
    app/controllers/sign/app/up/check/apple/confirmations_controller.rb
    app/controllers/sign/app/up/check/email/birthdates_controller.rb
    app/controllers/sign/app/up/check/email/otps_controller.rb
    app/controllers/sign/app/up/check/google/birthdates_controller.rb
    app/controllers/sign/app/up/check/telephone/birthdates_controller.rb
    app/controllers/sign/app/up/check/telephone/otps_controller.rb
    app/controllers/sign/app/up/check/telephone/passcodes_controller.rb
    app/controllers/sign/app/up/check/telephone/passkeys_controller.rb
    app/controllers/sign/app/up/emails_controller.rb
    app/controllers/sign/app/up/guard/apples_controller.rb
    app/controllers/sign/app/up/guard/emails_controller.rb
    app/controllers/sign/app/up/guard/googles_controller.rb
    app/controllers/sign/app/up/guard/telephones_controller.rb
    app/controllers/sign/app/up/telephones_controller.rb
    app/controllers/sign/app/verification/emails_controller.rb
    app/controllers/sign/com/in/challenges_controller.rb
    app/controllers/sign/com/in/emails_controller.rb
    app/controllers/sign/com/in/guards_controller.rb
    app/controllers/sign/com/in/passkeys_controller.rb
    app/controllers/sign/com/in/secret_credentials_controller.rb
    app/controllers/sign/com/in/sessions_controller.rb
    app/controllers/sign/com/settings/passkeys_controller.rb
    app/controllers/sign/com/settings/sessions_controller.rb
    app/controllers/sign/com/sign_ins_controller.rb
    app/controllers/sign/com/sign_ups_controller.rb
    app/controllers/sign/com/up/check/email/birthdates_controller.rb
    app/controllers/sign/com/up/check/email/otps_controller.rb
    app/controllers/sign/com/up/check/telephone/birthdates_controller.rb
    app/controllers/sign/com/up/check/telephone/otps_controller.rb
    app/controllers/sign/com/up/check/telephone/passcodes_controller.rb
    app/controllers/sign/com/up/check/telephone/passkeys_controller.rb
    app/controllers/sign/com/up/emails_controller.rb
    app/controllers/sign/com/up/guard/emails_controller.rb
    app/controllers/sign/com/up/guard/telephones_controller.rb
    app/controllers/sign/com/up/telephones_controller.rb
    app/controllers/sign/com/verification/emails_controller.rb
    app/controllers/sign/org/in/challenges_controller.rb
    app/controllers/sign/org/in/guards_controller.rb
    app/controllers/sign/org/in/passkeys_controller.rb
    app/controllers/sign/org/in/secret_credentials_controller.rb
    app/controllers/sign/org/in/sessions_controller.rb
    app/controllers/sign/org/settings/passkeys_controller.rb
    app/controllers/sign/org/settings/sessions_controller.rb
    app/controllers/sign/org/sign_ins_controller.rb
    app/controllers/sign/org/sign_ups_controller.rb
    app/controllers/sign/org/up/invitations_controller.rb
    app/controllers/acme/app/jwks_controller.rb
    app/controllers/acme/com/jwks_controller.rb
    app/controllers/acme/com/edge/v0/token/refreshes_controller_base.rb
    app/controllers/acme/org/jwks_controller.rb
    app/controllers/sign/app/settings/emails/registrations_controller.rb
    app/controllers/sign/app/in/challenge/passkeys_controller.rb
    app/controllers/sign/app/in/challenge/totps_controller.rb
    app/controllers/sign/com/in/challenge/passkeys_controller.rb
    app/controllers/sign/org/in/challenge/passkeys_controller.rb
  ).to_set.freeze

  # Patterns that are always forbidden regardless of allowlist status.
  # These detect regressions to the specific patterns cleaned up on this branch.
  FORBIDDEN_PATTERNS = [
    # Check-family controllers must not inherit Checkpoint implementations.
    {
      description: "Check namespace must not inherit Checkpoint namespace",
      glob: "app/controllers/sign/**/*_controller.rb",
      pattern: /class\s+\S+::Checks?(?:::\S+)?Controller\s*<\s*\S+::Checkpoints?(?:::\S+)?Controller/,
    },
    # Sign::*/Sign::In::Check* controllers must not inherit Sign::*/In::Checks*.
    # This was the direct violation fixed on this branch.
    {
      description: "Sign::*/Sign::In::Check* must not inherit Sign::*/In::Checks*",
      glob: "app/controllers/sign/*/sign/in/*checks*_controller.rb",
      pattern: /class\s+\S+Controller\s*<\s*::Sign::\w+::In::Checks?Controller/,
    },
  ].freeze

  # Scans all controller source files and returns paths (relative to Rails.root)
  # whose class declaration inherits from a non-approved base.
  # Approved bases: ApplicationController, BareController, ActionController::Base,
  # RedirectOnlyController, PreAccessController, FullAccessController,
  # PreferencesBaseController, and any class defined in PERMITTED_LOCAL_BASES.
  APPROVED_BASE_PATTERN = /
    ApplicationController
    | BareController
    | ActionController
    | RedirectOnlyController
    | PreAccessController
    | FullAccessController
    | PreferencesBaseController
    | ::Base\b
    | BaseController\b
  /x

  test "no new controller-to-controller inheritance violations are introduced" do
    detected = detect_inheritance_violations

    new_violations = detected - KNOWN_VIOLATIONS
    stale_entries  = KNOWN_VIOLATIONS - detected

    messages = []

    unless new_violations.empty?
      header = "New controller-to-controller inheritance violations " \
               "(fix inheritance or add to KNOWN_VIOLATIONS with a documented reason):"
      messages << "#{header}\n#{new_violations.sort.map { |p| "  #{p}" }.join("\n")}"
    end

    unless stale_entries.empty?
      messages << "KNOWN_VIOLATIONS entries that no longer exist or are now fixed (remove them):\n" \
                  "#{stale_entries.sort.map { |p| "  #{p}" }.join("\n")}"
    end

    assert_empty messages, messages.join("\n\n")
  end

  test "forbidden inheritance patterns are not present anywhere" do
    FORBIDDEN_PATTERNS.each do |rule|
      violations =
        Rails.root.glob(rule.fetch(:glob)).filter_map do |path|
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          next unless content.match?(rule.fetch(:pattern))

          path.relative_path_from(Rails.root).to_s
        end

      assert_empty violations,
                   "#{rule.fetch(:description)} — forbidden inheritance found:\n#{violations.join("\n")}"
    end
  end

  private

  def detect_inheritance_violations
    Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
      relative = path.relative_path_from(Rails.root).to_s
      next if PERMITTED_LOCAL_BASES.include?(relative)

      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

      # Extract the inheritance clause from the class declaration.
      match = content.match(/class\s+\S+Controller\s*<\s*(\S+)/)
      next unless match

      superclass_ref = match[1]
      next if superclass_ref.match?(APPROVED_BASE_PATTERN)

      relative
    end.to_set
  end
end
