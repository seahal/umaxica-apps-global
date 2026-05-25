# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    class WithdrawalGateInvariantTest < ActionDispatch::IntegrationTest
      fixtures_none!

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      setup do
        ensure_client_token_reference_records!
        ClientToken.skip_callback(:validation, :before, :ensure_device_session_record)
        @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
        host! @host
      end

      teardown do
        ClientToken.set_callback(:validation, :before, :ensure_device_session_record)
      end

      test "closing resource is redirected away from protected html routes" do
        user, headers = withdrawal_user_and_headers(:closing)

        get sign_app_configuration_sessions_url(ri: "jp"), headers: headers

        assert_predicate user.reload, :closing?
        assert_response :redirect
        assert_redirected_to edit_sign_app_configuration_withdrawal_path(ri: "jp")
      end

      test "suspended resource gets withdrawal required on json protected routes" do
        _user, headers = withdrawal_user_and_headers(:suspended)

        get sign_app_configuration_sessions_url(ri: "jp"),
            headers: headers.merge("Accept" => "application/json")

        assert_response :forbidden
        assert_equal "WITHDRAWAL_REQUIRED", response.parsed_body["error"]
      end

      test "terminated resource is redirected away from protected html routes" do
        user, headers = withdrawal_user_and_headers(:terminated)

        get sign_app_configuration_sessions_url(ri: "jp"), headers: headers

        assert_predicate user.reload, :terminated?
        assert_response :redirect
        assert_redirected_to edit_sign_app_configuration_withdrawal_path(ri: "jp")
      end

      test "withdrawal allowlist route remains reachable" do
        _user, headers = withdrawal_user_and_headers(:closing)

        get new_sign_app_configuration_withdrawal_url(ri: "jp"), headers: headers

        assert_response :success
      end

      test "application controllers do not skip the withdrawal gate" do
        allowlist = {
          # Edge cookie endpoints are reviewed self-defending preference/auth cookie APIs.
          "app/controllers/apex/app/edge/v0/cookies_controller.rb" => "edge cookie endpoint owns its own auth boundary",
          "app/controllers/apex/com/edge/v0/cookies_controller.rb" => "edge cookie endpoint owns its own auth boundary",
          # DBSC endpoints must process device-session challenge state before the normal withdrawal gate.
          "app/controllers/apex/app/edge/v0/dbsc_controller.rb" =>
            "DBSC edge endpoint owns its device binding boundary",
          "app/controllers/apex/com/edge/v0/dbsc_controller.rb" =>
            "DBSC edge endpoint owns its device binding boundary",
          "app/controllers/apex/org/edge/v0/dbsc_controller.rb" =>
            "DBSC edge endpoint owns its device binding boundary",
        }

        assert allowlist.values.all?(&:present?), "Withdrawal gate skip allowlist entries require reasons"

        offenders =
          Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(/skip_before_action\s+:enforce_withdrawal_gate!/)
              next if allowlist.key?(relative_path)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "Withdrawal gate skips require explicit invariant allowlist:\n#{offenders.join("\n")}"
      end

      private

      def ensure_client_token_reference_records!
        ClientTokenStatus.ensure_defaults!
        ClientTokenKind.ensure_defaults!
        ClientTokenBindingMethod.ensure_defaults!
        ClientTokenDbscStatus.ensure_defaults!
      end

      def withdrawal_user_and_headers(state)
        user = create_client
        apply_withdrawal_state!(user, state)
        token = ClientToken.create!(
          user: user,
          user_token_status_id: ClientTokenStatus::NOTHING,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          device_id: "withdrawal-gate-#{state}",
          discarded_at: 1.day.from_now,
        )
        satisfy_user_verification(token)
        token.update!(last_step_up_at: Time.current, last_step_up_scope: "withdrawal")

        [
          user,
          {
            "X-TEST-CURRENT-USER" => user.id.to_s,
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          },
        ]
      end

      def apply_withdrawal_state!(user, state)
        case state
        when :closing
          user.update!(withdrawal_started_at: 1.hour.ago)
        when :suspended
          user.update!(
            withdrawal_started_at: 2.hours.ago,
            deactivated_at: 1.hour.ago,
            discarded_at: 1.day.from_now,
            purged_at: 31.days.from_now,
          )
        when :terminated
          user.update_columns(
            withdrawal_started_at: 3.hours.ago,
            deactivated_at: 2.hours.ago,
            discarded_at: 2.hours.ago,
            purged_at: 1.hour.ago,
            terminated_at: 30.minutes.ago,
          )
        else
          raise ArgumentError, "unknown withdrawal state: #{state}"
        end
      end

      def create_client
        ensure_user_reference_records!
        Client.create!(
          status_id: ClientStatus::NOTHING,
          visibility_id: ClientVisibility::USER,
          multi_factor_id: ClientMultiFactor::NOTHING,
          multi_factor_status_id: ClientMultiFactorStatus::UNCONFIGURED,
        )
      end
    end
  end
end
