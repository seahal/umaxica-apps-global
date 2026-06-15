# typed: false
# frozen_string_literal: true

module StepUpScopeCatalog
  APP = {
    "social_link" => %r{\A/settings/(?:google|apple)(?:\z|[?#])},
    "social_unlink" => %r{\A/?(?:social/|settings/(?:google|apple)(?:\z|[?#]))},
    "session_revoke_all" => %r{\A/settings/sessions},
    "withdrawal" => %r{\A/settings/withdrawal},
    "settings_email" => %r{\A/settings/emails},
    "settings_telephone" => %r{\A/settings/telephones},
    "settings_passkey" => %r{\A/settings/passkeys},
    "settings_mfa" => %r{\A/settings/mfa/challenge},
    "settings_secret_credential" => %r{\A/settings/secret_credentials},
    "settings_birthdate" => %r{\A/settings/birthdate(?:\z|[?#])},
    "settings_totp" => %r{\A/settings/totps},
    "settings_connection" => %r{\A/settings/connections},
  }.freeze

  COM = APP.except("settings_totp", "social_link").freeze

  ORG = {
    # Org links/unlinks only Google (no Apple). Link gating is enforced by
    # SocialAuth via SOCIAL_LINK_SCOPE; org must therefore offer a
    # "social_link" scope or operator Google linking can never satisfy step-up.
    "social_link" => %r{\A/settings/google(?:\z|[?#])},
    "social_unlink" => %r{\A/?(?:social/|settings/google(?:\z|[?#]))},
    "session_revoke_all" => %r{\A(?:/settings/sessions|/support/(?:clients|visitors|operators)/\d+/sessions/)},
    "withdrawal" => %r{\A/settings/withdrawal},
    "settings_email" => %r{\A/settings/emails},
    "settings_telephone" => %r{\A/settings/telephones},
    "settings_passkey" => %r{\A/settings/passkeys},
    "settings_mfa" => %r{\A/settings/mfa/challenge},
    "settings_secret_credential" => %r{\A/settings/secret_credentials},
    "settings_birthdate" => %r{\A/settings/birthdate(?:\z|[?#])},
    "settings_connection" => %r{\A/settings/connections},
    "operator_lifecycle" => %r{\A/settings/operator_lifecycle_requests},
  }.freeze
end
