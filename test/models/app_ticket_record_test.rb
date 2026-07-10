# typed: false
# frozen_string_literal: true

require "test_helper"

class AppTicketRecordTest < ActiveSupport::TestCase
  fixtures :client_tokens, :clients, :client_token_kinds, :client_token_statuses

  test "should be abstract class" do
    assert_predicate AppTicketRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator AppTicketRecord, :<, ApplicationRecord
  end

  test "should connect to app_ticket database" do
    # Test that the model is configured to use the app_ticket database
    # Note: This is a basic structural test
    assert_respond_to AppTicketRecord, :connection_db_config
  end

  test "as_json excludes sensitive refresh token fields by default" do
    token = client_tokens(:one)

    payload = token.as_json

    assert_not payload.key?("refresh_token_digest")
    assert_not payload.key?("refresh_token_family_id")
    assert_not payload.key?("refresh_token_generation")
    assert_not payload.key?("id")
    assert_equal token.public_id, payload["public_id"]
  end

  test "as_json merges except options" do
    token = client_tokens(:one)

    payload = token.as_json(except: [:public_id])

    assert_not payload.key?("public_id")
    assert_not payload.key?("refresh_token_digest")
  end
end
