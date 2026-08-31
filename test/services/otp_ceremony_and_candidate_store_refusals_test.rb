# typed: false
# frozen_string_literal: true

require "test_helper"

# Both of these bind a ceremony to one surface and one channel. Every refusal
# below is a case where the binding does not hold: a sign-up ticket from another
# surface, a channel the ticket is not waiting on, or a stored candidate whose
# payload no longer parses. Each has to raise rather than fall through, because
# falling through would run the ceremony against the wrong record.
class OtpCeremonyAndCandidateStoreRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def ceremony(surface:, channel:, subject:)
    SignOtpCeremony.new(purpose: :sign_up, surface: surface, channel: channel, subject: subject)
  end

  test "a sign-up ticket from another surface does not match the ceremony's surface" do
    app_ticket = ClientSignUpFlow.new
    com_ticket = VisitorSignUpFlow.new

    assert ceremony(surface: :app, channel: :email, subject: app_ticket).send(:subject_matches_surface?)
    assert ceremony(surface: :com, channel: :email, subject: com_ticket).send(:subject_matches_surface?)
    assert_not ceremony(surface: :app, channel: :email, subject: com_ticket).send(:subject_matches_surface?)
    assert_not ceremony(surface: :org, channel: :email, subject: app_ticket).send(:subject_matches_surface?)
  end

  test "each surface and channel pair names its own record class and an unknown pair is refused" do
    {
      [:app, :email] => ClientEmail,
      [:app, :telephone] => ClientTelephone,
      [:com, :email] => VisitorEmail,
      [:com, :telephone] => VisitorTelephone,
    }.each do |(surface, channel), record_class|
      assert_equal record_class,
                   ceremony(surface: surface, channel: channel, subject: nil).send(:expected_record_class)
    end

    error =
      assert_raises(ArgumentError) do
        ceremony(surface: :org, channel: :email, subject: nil).send(:expected_record_class)
      end

    assert_match(/unsupported OTP record scope/, error.message)
  end

  # A record that does not track its own cooldown falls back to the last-sent
  # timestamp. A blank or sentinel timestamp means nothing was ever sent, which is
  # not a cooldown -- reading it as one would block the first send entirely.
  test "a record with no cooldown of its own falls back to when it last sent" do
    subject = ceremony(surface: :app, channel: :email, subject: nil)
    record_class = Struct.new(:otp_last_sent_at)

    assert_not subject.send(:cooldown_active?, record_class.new(nil))
    assert_not subject.send(:cooldown_active?, record_class.new(-Float::INFINITY))
    assert_not subject.send(:cooldown_active?, record_class.new(1.hour.ago))
    assert subject.send(:cooldown_active?, record_class.new(1.second.ago))
    assert_not subject.send(:cooldown_active?, Object.new)
  end

  test "a record that tracks its own cooldown is asked rather than inferred from" do
    subject = ceremony(surface: :app, channel: :email, subject: nil)
    record = Struct.new(:otp_cooldown_active?, :otp_last_sent_at).new(true, 1.hour.ago)

    assert subject.send(:cooldown_active?, record)
  end

  # A stored candidate's payload is deserialised on every read. A payload that no
  # longer parses is refused as invalid rather than half-built into a principal.
  test "a candidate payload that no longer parses is refused as invalid" do
    [
      { "principal" => { "provider" => "google" } },
      {
        "principal" => {
          "provider" => "google",
          "subject" => "sub-1",
          "issuer" => "https://example.test",
          "audience" => "client-1",
          "verified_at" => "not-a-timestamp",
          "verification_authority" => "id_token",
        },
      },
    ].each do |payload|
      error =
        assert_raises(IdentitySocialCeremonyContract::Error) do
          IdentitySocialCeremonyCandidateStore.new.send(:callback_result_from, payload)
        end

      assert_match(/social auth candidate is invalid/, error.message)
    end
  end

  # Only the two providers this surface federates with may be rebuilt from a
  # stored candidate; anything else means the row was written by something that
  # is no longer trusted to name a provider.
  test "a candidate naming a provider the surface does not federate with is refused" do
    payload = {
      "principal" => {
        "provider" => "line",
        "subject" => "sub-1",
        "issuer" => "https://example.test",
        "audience" => "client-1",
        "verified_at" => Time.current.utc.iso8601,
        "verification_authority" => "id_token",
      },
    }

    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyCandidateStore.new.send(:callback_result_from, payload)
      end

    assert_match(/social auth candidate is invalid/, error.message)
  end

  test "a candidate naming a federated provider is rebuilt as a verified principal" do
    %w(apple google).each do |provider|
      payload = {
        "principal" => {
          "provider" => provider,
          "subject" => "sub-1",
          "issuer" => "https://example.test",
          "audience" => "client-1",
          "verified_at" => Time.current.utc.iso8601,
          "verification_authority" => "id_token",
        },
      }

      result = IdentitySocialCeremonyCandidateStore.new.send(:callback_result_from, payload)

      assert_equal provider, result.principal.provider
      assert_nil result.credential_candidate
    end
  end
end
