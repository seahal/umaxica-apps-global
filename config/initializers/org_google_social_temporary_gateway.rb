# typed: false
# frozen_string_literal: true

require Rails.root.join("app/services/sign/social/temporary_signup_gate").to_s

Sign::Social::TemporarySignupGate.validate_production_configuration!
