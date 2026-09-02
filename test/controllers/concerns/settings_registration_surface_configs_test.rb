# typed: false
# frozen_string_literal: true

require "test_helper"

# Each settings-registration concern maps a surface name onto that surface's own
# record class, status ids and audit event. The mapping is closed on purpose: a
# surface outside the three must stop the ceremony by name, because falling back
# to any of them would write one surface's credential into another's table.
class SettingsRegistrationSurfaceConfigsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(concern)
    Class.new do
      include concern

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  test "the email registration config is closed to the three surfaces" do
    subject = harness(SignSettingsEmailRegistration)

    assert_equal ClientEmail, subject.invoke(:settings_email_registration_config, "app").fetch(:record_class)
    assert_raises(IdentityEmailCeremonyContract::Error) do
      subject.invoke(:settings_email_registration_config, "net")
    end
  end

  test "the telephone registration config is closed to the three surfaces" do
    subject = harness(SignSettingsTelephoneRegistration)

    assert_equal ClientTelephone, subject.invoke(:settings_telephone_registration_config, "app").fetch(:record_class)
    assert_raises(IdentityTelephoneCeremony::Error) do
      subject.invoke(:settings_telephone_registration_config, "net")
    end
  end

  test "the passkey registration config is closed to the three surfaces" do
    subject = harness(SignSettingsPasskeyRegistration)

    assert_equal ClientPasskey, subject.invoke(:settings_passkey_registration_config, "app").fetch(:record_class)
    assert_raises(IdentityPasskeyCeremonyContract::Error) do
      subject.invoke(:settings_passkey_registration_config, "net")
    end
  end

  test "secret credential creation is closed to the three surfaces" do
    subject = harness(SignSettingsSecretCredentialRegistration)

    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      subject.invoke(
        :create_settings_secret_credential!,
        surface: "net", actor: nil, record_class: nil, name: "n", enabled: true, raw_secret_credential: "s",
      )
    end
  end

  test "a candidate is referenced by its public id and falls back to its row id" do
    subject = harness(SignSettingsEmailRegistration)
    with_public_id = Struct.new(:public_id, :id).new("pub-1", 7)
    without_public_id = Struct.new(:id).new(7)

    assert_equal "pub-1", subject.invoke(:email_candidate_ref, with_public_id)
    assert_equal "7", subject.invoke(:email_candidate_ref, without_public_id)
  end

  test "a telephone candidate is referenced by its public id and falls back to its row id" do
    subject = harness(SignSettingsTelephoneRegistration)
    with_public_id = Struct.new(:public_id, :id).new("pub-2", 9)
    without_public_id = Struct.new(:id).new(9)

    assert_equal "pub-2", subject.invoke(:telephone_candidate_ref, with_public_id)
    assert_equal "9", subject.invoke(:telephone_candidate_ref, without_public_id)
  end
end
