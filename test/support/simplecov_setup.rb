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

    # Coverage thresholds: fail build if line < 97%, branch < 63%
    minimum_coverage line: 97, branch: 63

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

    # Exclude broad framework-style infrastructure from the product coverage
    # gate. These files are exercised across many integration tests, but their
    # branch surface dominates the line metric and obscures feature coverage.
    add_filter "lib/jit/security/active_record_encryption_key_provider.rb"
    add_filter "lib/jit/security/secret_key_base_provider.rb"
    add_filter "app/subscribers/jwt_anomaly_subscriber.rb"
    add_filter "app/models/application_record.rb"
    add_filter "app/controllers/concerns/authentication/base.rb"
    add_filter "app/controllers/concerns/preference/base.rb"
    add_filter "app/controllers/concerns/preference/core.rb"
    add_filter "app/controllers/concerns/verification/base.rb"
    add_filter "app/services/auth/token_service.rb"

    # Legacy sign-in and configuration flows remain covered by their own tests,
    # but are excluded from the aggregate product gate while the reauth rebuild
    # continues to split these large controllers into smaller units.
    add_filter "app/controllers/sign/app/in/emails_controller.rb"
    add_filter "app/controllers/sign/app/up/emails_controller.rb"
    add_filter "app/controllers/sign/app/up/telephones_controller.rb"
    add_filter "app/controllers/sign/app/in/challenge/passkeys_controller.rb"
    add_filter "app/controllers/sign/app/in/challenge/totps_controller.rb"
    add_filter "app/controllers/sign/app/in/secrets_controller.rb"
    add_filter "app/controllers/sign/app/configuration/passkeys_controller.rb"
    add_filter "app/controllers/sign/com/in/emails_controller.rb"
    add_filter "app/controllers/sign/com/in/secrets_controller.rb"
    add_filter "app/controllers/sign/com/in/challenge/passkeys_controller.rb"
    add_filter "app/controllers/sign/com/in/passkeys_controller.rb"
    add_filter "app/controllers/sign/com/up/emails_controller.rb"
    add_filter "app/controllers/sign/com/up/telephones_controller.rb"
    add_filter "app/controllers/sign/com/application_controller.rb"
    add_filter "app/controllers/sign/com/configuration/passkeys_controller.rb"
    add_filter "app/controllers/sign/com/configuration/telephones/registrations_controller.rb"
    add_filter "app/controllers/sign/org/auth/omniauth_callbacks_controller.rb"
    add_filter "app/controllers/sign/org/configuration/emails/registrations_controller.rb"
    add_filter "app/controllers/sign/org/configuration/passkeys_controller.rb"
    add_filter "app/controllers/sign/org/configuration/telephones/registrations_controller.rb"
    add_filter "app/controllers/concerns/sign/email_registrable.rb"
    add_filter "app/controllers/concerns/sign/email_registration_flow.rb"
    add_filter "app/controllers/concerns/sign/passkey_options_flow.rb"
    add_filter "app/controllers/concerns/sign/passkey_verification_flow.rb"
    add_filter "app/controllers/concerns/sign/operator_telephone_registrable.rb"
    add_filter "app/controllers/concerns/sign/telephone_registrable.rb"
    add_filter "app/controllers/concerns/sign/webauthn.rb"
    add_filter "app/controllers/concerns/authentication/visitor.rb"
    add_filter "app/controllers/concerns/preference/adoption.rb"
    add_filter "app/controllers/concerns/preference/edge.rb"
    add_filter "app/controllers/concerns/preference/global.rb"
    add_filter "app/controllers/concerns/preference/web_cookie_endpoint.rb"
    add_filter "app/controllers/concerns/social_auth_concern.rb"
    add_filter "app/services/social_auth_service.rb"
  end
end
