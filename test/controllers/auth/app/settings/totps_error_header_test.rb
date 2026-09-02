# typed: false
# frozen_string_literal: true

require "test_helper"

# A rejected authenticator edit is summarised above the form. The summary names
# the model only where the page does not already, and a record with no errors
# gets no summary at all rather than an empty heading.
class AuthAppSettingsTotpsErrorHeaderTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::App::Settings::TotpsController
    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @totp = ClientTotpCredential.new
    @harness.instance_variable_set(:@totp, @totp)
  end

  test "a record with no errors gets no summary" do
    assert_nil @harness.invoke(:totp_error_header, model: false)
    assert_nil @harness.invoke(:totp_error_header, model: true)
  end

  test "a rejected record is summarised with the model name and the error count" do
    @totp.errors.add(:title, :blank)

    assert_equal I18n.t("errors.template.header", model: ClientTotpCredential.model_name.human, count: 1),
                 @harness.invoke(:totp_error_header, model: true)
  end
end
