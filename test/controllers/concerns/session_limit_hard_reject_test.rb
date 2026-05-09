# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionLimitHardRejectTest < ActionDispatch::IntegrationTest
  fixtures :users

  class TestController < ApplicationController
    include Authentication::User

    public_strict!

    def create
      user = User.find(params[:user_id])
      result = log_in(user, require_totp_check: false)

      if result[:status] == :session_limit_hard_reject
        respond_to do |format|
          format.html { render plain: result[:message], status: result[:http_status] }
          format.json {
            render json: { error: result[:message], error_code: "session_limit_hard_reject" },
                   status: result[:http_status]
          }
        end
      else
        render json: { status: "ok" }, status: :ok
      end
    end
  end

  setup do
    @user = users(:one)
    UserToken.where(user_id: @user.id).delete_all
    2.times do
      token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
      token.rotate_refresh_token!
    end
    restricted = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted.rotate_refresh_token!(lapses_at: 15.minutes.from_now)

    Rails.application.routes.draw do
      post "/test/hard_reject_login" => "session_limit_hard_reject_test/test#create"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "hard reject returns 409 for html and does not create new token" do
    before_count = UserToken.where(user_id: @user.id).count

    post "/test/hard_reject_login", params: { user_id: @user.id }

    assert_response :conflict
    assert_equal Authentication::Base::SESSION_LIMIT_HARD_REJECT_MESSAGE, response.body
    assert_equal before_count, UserToken.where(user_id: @user.id).count
  end

  test "hard reject returns 409 for json and does not create new token" do
    before_count = UserToken.where(user_id: @user.id).count

    post "/test/hard_reject_login",
         params: { user_id: @user.id },
         as: :json

    assert_response :conflict
    assert_equal "session_limit_hard_reject", response.parsed_body["error_code"]
    assert_equal before_count, UserToken.where(user_id: @user.id).count
  end
end
