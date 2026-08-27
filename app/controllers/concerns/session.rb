# typed: false
# frozen_string_literal: true

module Session
  extend ActiveSupport::Concern

  # Registered as a `before_action` on every surface. Flash lives in the session cookie, which
  # production issues as `__Host-session` without a Domain attribute (see
  # JitSessionCookieConfig#session_options), so it is already host-locked and nothing needs
  # resetting. Development and test scope the same cookie to the apex domain.
  def reset_flash
    nil
  end
end
