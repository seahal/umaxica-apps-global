# typed: false
# frozen_string_literal: true

module StepUp
  module ScopeCatalog
    APP = {
      "social_link" => %r{\A/configuration/(?:google|apple)(?:\z|[?#])},
      "social_unlink" => %r{\A/?(?:social/|configuration/(?:google|apple)(?:\z|[?#]))},
      "session_revoke_all" => %r{\A/configuration/sessions},
      "withdrawal" => %r{\A/configuration/withdrawal},
      "configuration_email" => %r{\A/configuration/emails},
      "configuration_telephone" => %r{\A/configuration/telephones},
      "configuration_passkey" => %r{\A/configuration/passkeys},
      "configuration_mfa" => %r{\A/configuration/mfa/challenge},
      "configuration_secret_credential" => %r{\A/configuration/secret_credentials},
      "configuration_birthdate" => %r{\A/configuration/birthdate(?:\z|[?#])},
      "configuration_totp" => %r{\A/configuration/totps},
      "configuration_connection" => %r{\A/configuration/connections},
    }.freeze

    COM = APP.except("configuration_totp", "social_link").freeze

    ORG = {
      # Org links/unlinks only Google (no Apple). Link gating is enforced by
      # SocialAuthConcern via SOCIAL_LINK_SCOPE; org must therefore offer a
      # "social_link" scope or operator Google linking can never satisfy step-up.
      "social_link" => %r{\A/configuration/google(?:\z|[?#])},
      "social_unlink" => %r{\A/?(?:social/|configuration/google(?:\z|[?#]))},
      "session_revoke_all" => %r{\A/configuration/sessions},
      "withdrawal" => %r{\A/configuration/withdrawal},
      "configuration_email" => %r{\A/configuration/emails},
      "configuration_telephone" => %r{\A/configuration/telephones},
      "configuration_passkey" => %r{\A/configuration/passkeys},
      "configuration_mfa" => %r{\A/configuration/mfa/challenge},
      "configuration_secret_credential" => %r{\A/configuration/secret_credentials},
      "configuration_birthdate" => %r{\A/configuration/birthdate(?:\z|[?#])},
      "configuration_connection" => %r{\A/configuration/connections},
      "operator_lifecycle" => %r{\A/configuration/operator_lifecycle_requests},
    }.freeze
  end
end
