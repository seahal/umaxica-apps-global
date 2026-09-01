# typed: false
# frozen_string_literal: true

require "test_helper"

# A ceremony result names its candidate by public id, and the committer resolves
# it inside the acting principal's own rows. Resolving outside that scope would
# let a result issued for one account commit a contact belonging to another, so
# a reference that names no row of this actor must not resolve at all.
class IdentityCeremonyCandidateLookupTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  def committer(klass, actor:, result:)
    instance = klass.allocate
    instance.instance_variable_set(:@actor, actor)
    instance.instance_variable_set(:@surface, "app")
    instance.define_singleton_method(:result) { result }
    instance
  end

  test "a telephone candidate is resolved inside the acting principal's own rows" do
    telephone = ClientTelephone.create!(
      user: @client, number: "+1234567700",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      confirm_policy: "1", confirm_using_mfa: "1",
    )
    subject = committer(
      IdentityTelephoneCeremonyFinalCommitter,
      actor: @client,
      result: { "telephone_candidate_ref" => telephone.public_id },
    )

    assert_equal telephone, subject.send(:find_candidate!)
  end

  test "a telephone candidate belonging to another principal does not resolve" do
    telephone = ClientTelephone.create!(
      user: @other, number: "+1234567701",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      confirm_policy: "1", confirm_using_mfa: "1",
    )
    subject = committer(
      IdentityTelephoneCeremonyFinalCommitter,
      actor: @client,
      result: { "telephone_candidate_ref" => telephone.public_id },
    )

    assert_raises(ActiveRecord::RecordNotFound) { subject.send(:find_candidate!) }
  end

  test "a result that names no telephone candidate is refused by name" do
    subject = committer(
      IdentityTelephoneCeremonyFinalCommitter, actor: @client, result: { "telephone_candidate_ref" => "" },
    )

    assert_raises(IdentityTelephoneCeremony::Error) { subject.send(:find_candidate!) }
  end

  test "an email candidate is resolved inside the acting principal's own rows" do
    email = ClientEmail.create!(
      user: @client,
      address: "candidate-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
      otp_private_key: ROTP::Base32.random_base32,
      otp_counter: "0",
    )
    subject = committer(
      IdentityEmailCeremonyFinalCommitter,
      actor: @client,
      result: { "email_candidate_ref" => email.public_id },
    )

    assert_equal email, subject.send(:find_candidate!)
  end
end
