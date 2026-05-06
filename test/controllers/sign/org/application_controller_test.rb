# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::Org
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    setup do
      host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
      @controller = Sign::Org::ApplicationController.new
      @controller.request = ActionDispatch::TestRequest.create(
        "rack.session" => {},
        "rack.session.options" => { id: SecureRandom.hex(16) },
      )
      @controller.response = ActionDispatch::TestResponse.new
      @staff =
        Staff.find_or_create_by!(id: 1) do |s|
          s.status_id = StaffStatus::NOTHING
        end
    end

    test "includes expected concerns" do
      assert_includes @controller.class, ::Preference::Global
      assert_includes @controller.class, RateLimit
    end

    test "am_i_user? returns false" do
      assert_not @controller.send(:am_i_user?)
    end

    test "authenticate_staff! allows access when staff is logged in" do
      # Mock header to simulate logged in staff
      @controller.request.headers["X-TEST-CURRENT-STAFF"] = @staff.id
      # Should not raise or redirect
      assert_nothing_raised do
        @controller.send(:authenticate_staff!)
      end
    end
  end
end
