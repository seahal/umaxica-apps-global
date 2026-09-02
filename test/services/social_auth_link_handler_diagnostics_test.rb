# typed: false
# frozen_string_literal: true

require "test_helper"

# Linking a social identity to an account is where two accounts can end up
# sharing one identity, so the handler records what it saw at each decision
# point. Those lines only exist at debug level; they must still be safe to
# build, and the conflicts they describe must still be refused.
class SocialAuthLinkHandlerDiagnosticsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @previous_level = Rails.logger.level
    Rails.logger.level = Logger::DEBUG
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  teardown do
    Rails.logger.level = @previous_level
  end

  def repository_returning(identity_for_user:, identity_for_uid:)
    repository = Object.new
    repository.define_singleton_method(:find_for_user) { |*, **| identity_for_user }
    repository.define_singleton_method(:find_by_subject) { |*, **| identity_for_uid }
    repository
  end

  def handler(repository:)
    SocialAuthLinkHandler.new(
      principal: nil,
      credential_candidate: nil,
      current_client: @client,
      repository: repository,
      provider: "google",
      uid: "uid-1",
    )
  end

  test "an account that already has this provider linked to a different uid is refused" do
    other_identity = Struct.new(:user_id, :uid, :provider).new(@client.id, "uid-2", "google")
    subject = handler(repository: repository_returning(identity_for_user: other_identity, identity_for_uid: nil))

    assert_raises(SocialAuth::ConflictError) { subject.call }
  end

  test "an identity that belongs to another account is refused" do
    foreign_identity = Struct.new(:user_id, :uid, :provider).new(@client.id + 1, "uid-1", "google")
    subject = handler(repository: repository_returning(identity_for_user: nil, identity_for_uid: foreign_identity))

    assert_raises(SocialAuth::ConflictError) { subject.call }
  end
end
