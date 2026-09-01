# typed: false
# frozen_string_literal: true

require "test_helper"

# Per-surface stores and typed payload envelopes. Each refuses a surface, subject
# or payload shape it was not built for, because the alternative is writing one
# surface's ceremony into another's table, or delivering a message assembled from
# two mutually exclusive payload formats.
class CeremonyReplayStoreAndPayloadRefusalsTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  test "each surface's telephone ceremony store writes to its own transaction table" do
    {
      "app" => ClientTelephoneCeremonyTransaction,
      "com" => VisitorTelephoneCeremonyTransaction,
      "org" => OperatorTelephoneCeremonyTransaction,
    }.each do |surface, model|
      store = IdentityTelephoneCeremonyReplayStore.for(surface)

      assert_equal model, store.send(:transaction_class)
    end
  end

  test "a surface with no telephone ceremony table is refused rather than defaulted" do
    error = assert_raises(IdentityTelephoneCeremony::Error) { IdentityTelephoneCeremonyReplayStore.for("martian") }

    assert_match(/surface is invalid/, error.message)
  end

  test "a transaction round-trips through the store it was created by and is seen as consumed once" do
    store = IdentityTelephoneCeremonyReplayStore.for("app")
    created = store.create_transaction!(actor_ref: "actor-1", session_ref: "session-1", operation: "registration")

    assert_equal created.transaction_id, store.find_transaction!(created.transaction_id).transaction_id
    assert_not store.consumed?("never-issued-jti")

    created.update!(result_jti: "issued-jti")

    assert store.consumed?("issued-jti")
    assert_raises(ActiveRecord::RecordNotFound) { store.find_transaction!("no-such-transaction") }
  end

  # An avatar is bound to exactly one subject type. A type the operation does not
  # know has to raise rather than leave an avatar with no binding at all.
  test "an avatar subject type with no binding table is named in the error" do
    operation = AvatarProvisioning::Create.new(
      actor: clients(:one), subject_type: "martian", subject: clients(:one), avatar_params: {},
    )

    error = assert_raises(ArgumentError) { operation.send(:create_binding!, nil) }

    assert_match(/unsupported subject_type: "martian"/, error.message)
  end

  # The SMS job accepts a versioned encrypted envelope or the legacy fields, never
  # both: a mixed payload means two producers disagree about what is being sent.
  test "an SMS payload that mixes the two formats is refused" do
    job = Outbound::SmsDeliveryJob.new

    error =
      assert_raises(ArgumentError) do
        job.send(
          :delivery_payload,
          encrypted_payload: "envelope", to: "+15550000000", title: nil, encrypted_body: nil, body: nil,
        )
      end

    assert_match(/Mixed SMS job payload formats are not accepted/, error.message)
  end

  test "a plaintext or incomplete SMS payload is refused rather than delivered" do
    job = Outbound::SmsDeliveryJob.new

    plaintext =
      assert_raises(ArgumentError) do
        job.send(:delivery_payload, encrypted_payload: nil, to: "+1", title: "t", encrypted_body: nil, body: "hello")
      end

    assert_match(/Plaintext SMS job payload is no longer accepted/, plaintext.message)

    incomplete =
      assert_raises(ArgumentError) do
        job.send(:delivery_payload, encrypted_payload: nil, to: "+1", title: nil, encrypted_body: nil, body: nil)
      end

    assert_match(/Incomplete SMS job payload|Incomplete legacy SMS job payload/, incomplete.message)
  end

  test "a legacy SMS payload is decrypted into the delivered body" do
    job = Outbound::SmsDeliveryJob.new
    encrypted = OutboundSensitivePayload.encrypt_sms_body("your code is 123456")

    payload = job.send(
      :delivery_payload,
      encrypted_payload: nil, to: "+15550000000", title: "Umaxica", encrypted_body: encrypted, body: nil,
    )

    assert_equal "your code is 123456", payload.fetch(:body)
    assert_equal "+15550000000", payload.fetch(:to)
  end
end
