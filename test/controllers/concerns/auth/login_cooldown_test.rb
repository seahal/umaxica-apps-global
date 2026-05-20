# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthLoginCooldownTest < ActiveSupport::TestCase
  class CooldownHarness
    include Authentication::Base

    attr_accessor :session_data, :rendered

    def initialize
      @session_data = {}
      @rendered = nil
    end

    def session
      @session_data
    end

    def resource_type = "user"

    def resource_class = Client

    def token_class = ClientToken

    def audit_class = ClientChronicle

    def resource_foreign_key = :user_id

    def sign_in_url_with_return(_return_to) = "/sign/in"

    def am_i_user? = false

    def am_i_staff? = false

    def am_i_owner? = false

    def render(options = {})
      @rendered = options
    end
  end

  setup do
    @harness = CooldownHarness.new
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    Authentication::Base.login_cooldown_enabled = true
  end

  teardown do
    Authentication::Base.login_cooldown_enabled = false
  end

  test "LOGIN_COOLDOWN is 30 seconds" do
    assert_equal 30.seconds, Authentication::Base::LOGIN_COOLDOWN
  end

  test "LoginCooldownError is a StandardError" do
    assert_operator Authentication::Base::LoginCooldownError, :<, StandardError
  end

  test "check_login_cooldown! does not raise when no tokens exist" do
    assert_nothing_raised do
      @harness.send(:check_login_cooldown!, @user)
    end
  end

  test "check_login_cooldown! does not raise when last login was over 30 seconds ago" do
    OrgTicketRecord.connected_to(role: :writing) do
      ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    end

    travel 31.seconds do
      assert_nothing_raised do
        @harness.send(:check_login_cooldown!, @user)
      end
    end
  end

  test "check_login_cooldown! raises LoginCooldownError when last login was within 30 seconds" do
    OrgTicketRecord.connected_to(role: :writing) do
      ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    end

    assert_raises(Authentication::Base::LoginCooldownError) do
      @harness.send(:check_login_cooldown!, @user)
    end
  end

  test "check_login_cooldown! raises at exactly 30 seconds boundary" do
    OrgTicketRecord.connected_to(role: :writing) do
      ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    end

    travel 30.seconds do
      assert_raises(Authentication::Base::LoginCooldownError) do
        @harness.send(:check_login_cooldown!, @user)
      end
    end
  end

  test "check_login_cooldown! does not raise at 31 seconds" do
    OrgTicketRecord.connected_to(role: :writing) do
      ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    end

    travel 31.seconds do
      assert_nothing_raised do
        @harness.send(:check_login_cooldown!, @user)
      end
    end
  end

  test "check_login_cooldown! considers only the most recent token" do
    freeze_time do
      OrgTicketRecord.connected_to(role: :writing) do
        ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE, created_at: 60.seconds.ago)
        ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE, created_at: 10.seconds.ago)
      end

      assert_raises(Authentication::Base::LoginCooldownError) do
        @harness.send(:check_login_cooldown!, @user)
      end
    end
  end

  test "check_login_cooldown! ignores tokens of other clients" do
    other_user = clients(:two)

    OrgTicketRecord.connected_to(role: :writing) do
      ClientToken.create!(user: other_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    end

    assert_nothing_raised do
      @harness.send(:check_login_cooldown!, @user)
    end
  end

  test "check_login_cooldown! works for staff" do
    staff = Operator.first
    harness = CooldownHarness.new
    # Override token_class for staff
    harness.define_singleton_method(:token_class) { OperatorToken }

    OperatorToken.where(staff_id: staff.id).delete_all
    OrgTicketRecord.connected_to(role: :writing) do
      OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    end

    assert_raises(Authentication::Base::LoginCooldownError) do
      harness.send(:check_login_cooldown!, staff)
    end
  end

  test "render_login_cooldown renders plain text with 429 status" do
    @harness.send(:render_login_cooldown)

    assert_equal({ plain: Authentication::Base::LOGIN_COOLDOWN_MESSAGE, status: :too_many_requests }, @harness.rendered)
  end
end
