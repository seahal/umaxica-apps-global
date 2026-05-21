# typed: false
# frozen_string_literal: true

module StepUp
  module ScopeCatalog
    APP = {
      "social_unlink" => %r{\A/?(?:social/|configuration/(?:google|apple)(?:\z|[?#]))},
      "session_revoke_all" => %r{\A/configuration/sessions},
      "withdrawal" => %r{\A/configuration/withdrawal},
      "configuration_email" => %r{\A/configuration/emails},
      "configuration_telephone" => %r{\A/configuration/telephones},
      "configuration_passkey" => %r{\A/configuration/passkeys},
      "configuration_mfa" => %r{\A/configuration/mfa/challenge},
      "configuration_secret" => %r{\A/configuration/secrets},
      "configuration_birthdate" => %r{\A/configuration/birthdate(?:\z|[?#])},
      "configuration_totp" => %r{\A/configuration/totps},
      "configuration_connection" => %r{\A/configuration/connections},
    }.freeze

    COM = APP.except("configuration_totp").freeze

    ORG = {
      "social_unlink" => %r{\A/?(?:social/|configuration/google(?:\z|[?#]))},
      "session_revoke_all" => %r{\A/configuration/sessions},
      "withdrawal" => %r{\A/configuration/withdrawal},
      "configuration_email" => %r{\A/configuration/emails},
      "configuration_telephone" => %r{\A/configuration/telephones},
      "configuration_passkey" => %r{\A/configuration/passkeys},
      "configuration_mfa" => %r{\A/configuration/mfa/challenge},
      "configuration_secret" => %r{\A/configuration/secrets},
      "configuration_birthdate" => %r{\A/configuration/birthdate(?:\z|[?#])},
      "configuration_connection" => %r{\A/configuration/connections},
      "operator_lifecycle" => %r{\A/configuration/operator_lifecycle_requests},
    }.freeze
  end
end
