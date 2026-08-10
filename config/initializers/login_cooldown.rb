# frozen_string_literal: true

# Rapid re-login guard: a new session may not be issued within this window of the one
# issued before it (AuthenticationBase#check_login_cooldown!). A zero duration disables
# the gate, which is how the test suite exercises flows that log in repeatedly
# (test/support/login_cooldown_helper.rb).
Rails.application.config.x.authentication.login_cooldown = 30.seconds
