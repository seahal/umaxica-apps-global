# frozen_string_literal: true

require "test_helper"

class BaseOrgPublishingManagementRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
  PUBLIC_ID = "abcdefghijklmnopqrstu"

  CELLS = %w(info docs news help).product(%w(app com org)).freeze

  test "all twelve cells expose index show edit and update on public_id" do
    CELLS.each do |surface, audience|
      controller = "base/org/publishing/#{surface}/#{audience}/entries"

      index = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries",
        method: :get,
      )
      show = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}",
        method: :get,
      )
      edit = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}/edit",
        method: :get,
      )
      update = Rails.application.routes.recognize_path(
        "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}",
        method: :patch,
      )

      assert_equal controller, index.fetch(:controller), "#{surface}/#{audience} index"
      assert_equal "index", index.fetch(:action)
      assert_equal controller, show.fetch(:controller), "#{surface}/#{audience} show"
      assert_equal "show", show.fetch(:action)
      assert_equal PUBLIC_ID, show.fetch(:id)
      assert_equal controller, edit.fetch(:controller), "#{surface}/#{audience} edit"
      assert_equal "edit", edit.fetch(:action)
      assert_equal PUBLIC_ID, edit.fetch(:id)
      assert_equal controller, update.fetch(:controller), "#{surface}/#{audience} update"
      assert_equal "update", update.fetch(:action)
      assert_equal PUBLIC_ID, update.fetch(:id)
    end
  end

  test "publishing management routes do not expose create or destroy" do
    CELLS.each do |surface, audience|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{HOST}/publishing/#{surface}/#{audience}/entries",
          method: :post,
        )
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{HOST}/publishing/#{surface}/#{audience}/entries/#{PUBLIC_ID}",
          method: :delete,
        )
      end
    end
  end

  test "named helpers use params id as the public identifier" do
    path = Rails.application.routes.url_helpers.base_org_publishing_docs_app_entry_path(PUBLIC_ID)

    assert_equal "/publishing/docs/app/entries/#{PUBLIC_ID}", path
    assert_not_includes path, "/1"
  end
end
