# typed: false
# frozen_string_literal: true

require "test_helper"

class I18nRuntimeDefaultCleanupTest < ActiveSupport::TestCase
  LOCALES = %i(ja en).freeze

  KEYS = %w(
    meta.default_title
    defaults.never
    time.formats.short
    session_limit.edit.page_title
    sign.app.configuration.totp.index.new_link
    sign.app.configuration.withdrawal.recovery.link
    sign.app.configuration.withdrawal.recovery.page_title
    sign.app.configuration.withdrawal.recovery.deadline
    sign.app.configuration.withdrawal.recovery.available
    sign.app.configuration.withdrawal.recovery.submit
    sign.app.configuration.withdrawal.recovery.confirm
    sign.app.configuration.withdrawal.recovery.unavailable
    sign.app.verification.errors.no_passkey
    sign.org.in.back
    sign.org.in.session.restricted_notice
    sign.org.in.mfa.title
    sign.org.in.mfa.description
    sign.org.in.mfa.verification_failed
    sign.org.in.mfa.no_methods_available
    sign.org.in.mfa.methods.passkey
    sign.org.in.mfa.passkey.title
    sign.org.in.mfa.passkey.description
    sign.org.in.mfa.passkey.authenticate
    sign.org.in.mfa.passkey.back
    sign.org.in.mfa.passkey.success
    sign.org.verification.errors.no_passkey
    sign.org.configuration.google.show.disable
    sign.org.configuration.sessions.revoke.others_button
    sign.org.configuration.sessions.revoke.others_confirm
    help.app.contacts.new.submit
    help.app.contacts.new.cancel
    help.com.contacts.new.submit
    help.com.contacts.new.cancel
    help.org.contacts.new.submit
    help.org.contacts.new.cancel
    errors.invalid_authenticity_token
  ).freeze

  test "runtime default cleanup keys exist for ja and en" do
    LOCALES.each do |locale|
      KEYS.each do |key|
        assert I18n.exists?(key, locale), "missing #{key} for #{locale}"
      end
    end
  end
end
