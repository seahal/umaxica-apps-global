# frozen_string_literal: true

# Adjusts the configured login cooldown window for tests that log the same resource in
# repeatedly. The window is real application configuration, so the application code holds
# no test-only switch.
module LoginCooldownHelper
  def login_cooldown
    Rails.application.config.x.authentication.login_cooldown
  end

  def login_cooldown=(duration)
    Rails.application.config.x.authentication.login_cooldown = duration
  end

  def with_login_cooldown(duration)
    original = login_cooldown
    self.login_cooldown = duration
    yield
  ensure
    self.login_cooldown = original
  end
end
