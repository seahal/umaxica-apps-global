# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialsUpdateTest < ActiveSupport::TestCase
  test "updates normalized attributes and records the client audit atomically" do
    actor = Client.new(id: 41)
    secret_credential = Object.new
    assigned_name = nil
    assigned_status = nil
    saved = false
    audit = nil
    secret_credential.define_singleton_method(:id) { 73 }
    secret_credential.define_singleton_method(:name=) { |value| assigned_name = value }
    secret_credential.define_singleton_method(:user_secret_status_id=) { |value| assigned_status = value }
    secret_credential.define_singleton_method(:save!) { saved = true }

    ClientChronicle.stub(:transaction, ->(&block) { block.call }) do
      ClientSecretCredential.stub(:transaction, ->(&block) { block.call }) do
        ChronicleRecord.stub(:connected_to, ->(**, &block) { block.call }) do
          ClientChronicleEvent.stub(:find_or_create_by!, true) do
            ClientChronicleLevel.stub(:find_or_create_by!, true) do
              ClientChronicle.stub(:create!, ->(**attrs) { audit = attrs }) do
                result = ClientSecretCredentialsUpdate.call(
                  actor: actor,
                  secret_credential: secret_credential,
                  params: { name: "  Production key  ", enabled: "false" },
                )

                assert_same secret_credential, result.secret_credential
              end
            end
          end
        end
      end
    end

    assert_equal "Production key", assigned_name
    assert_equal ClientSecretCredential.status_id_for(:revoked), assigned_status
    assert saved
    assert_same actor, audit.fetch(:actor)
    assert_equal ClientSecretCredentialsUpdate::EVENT_ID, audit.fetch(:event_id)
    assert_equal({ action: ClientSecretCredentialsUpdate::ACTION }, audit.fetch(:context))
  end
end
