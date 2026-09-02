# typed: false
# frozen_string_literal: true

require "test_helper"

# Two seams the social login handler goes through: the reference rows a new
# account depends on are created idempotently on the writer, and a new identity
# is always built through the provider's own repository so the provider-specific
# columns are filled in one place.
class SocialAuthLoginHandlerSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def handler(repository:)
    SocialAuthLoginHandler.new(
      principal: :principal,
      credential_candidate: :candidate,
      repository: repository,
      provider: "google",
      uid: "uid-1",
    )
  end

  test "a reference row that does not exist yet is created with its code" do
    unused_id = (ClientChronicleLevel.maximum(:id).to_i + 1000)
    subject = handler(repository: Object.new)

    assert_difference -> { ClientChronicleLevel.count }, 1 do
      subject.send(:ensure_reference_record!, ClientChronicleLevel, unused_id, "SEAM")
    end

    # A second call for the same id is idempotent: reference rows are shared and
    # must never be duplicated by a concurrent sign-up.
    assert_no_difference -> { ClientChronicleLevel.count } do
      subject.send(:ensure_reference_record!, ClientChronicleLevel, unused_id, "SEAM")
    end
  end

  test "a new identity is built through the provider repository" do
    repository = Object.new
    built = nil
    repository.define_singleton_method(:build_for_user) do |user:, principal:, credential_candidate:|
      built = [user, principal, credential_candidate]
    end

    handler(repository: repository).send(:build_identity_for_user, :the_user)

    assert_equal %i(the_user principal candidate), built
  end
end
