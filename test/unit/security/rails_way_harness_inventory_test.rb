# typed: false
# frozen_string_literal: true

require "test_helper"

class RailsWayHarnessInventoryTest < ActiveSupport::TestCase
  fixtures_none!

  CONTROLLER_CONCERN_SIDE_EFFECT_PATTERN =
    /\b(?:before_action|after_action|around_action|prepend_before_action|prepend_around_action|
          helper_method|rescue_from|layout|protect_from_forgery|allow_browser|skip_before_action)\b/x

  MODEL_CONCERN_SIDE_EFFECT_PATTERN =
    /\b(?:validates|validate|scope|before_validation|before_create|after_create|after_initialize|
          attribute|enum|class_attribute|belongs_to|has_many|has_one|normalizes)\b/x

  REVIEWED_MODEL_CONCERN_SIDE_EFFECTS = {
    "app/models/concerns/account.rb" => [1, "legacy ActiveRecord validation concern; move deliberately"],
    "app/models/concerns/acme_logout_transactionable.rb" => [
      7,
      "reviewed sign-out transaction concern",
    ],
    "app/models/concerns/actor_lifecycle_consistency.rb" => [2, "legacy Actor lifecycle invariant concern"],
    "app/models/concerns/administrative_access_lockable.rb" => [
      4,
      "reviewed shared administrative access lock DSL concern",
    ],
    "app/models/concerns/banner_model.rb" => [8, "legacy ActiveRecord banner DSL concern"],
    "app/models/concerns/collective.rb" => [1, "legacy ActiveRecord validation concern"],
    "app/models/concerns/collective_membership.rb" => [7, "legacy ActiveRecord membership DSL concern"],
    "app/models/concerns/collective_unit.rb" => [4, "legacy closure-table lifecycle concern"],
    "app/models/concerns/core_rp_bridge.rb" => [9, "legacy Core RP bridge defaults and validations"],
    "app/models/concerns/dbsc_bindable.rb" => [1, "legacy DBSC session validation concern"],
    "app/models/concerns/device_sessionable.rb" => [3, "legacy device session token concern"],
    "app/models/concerns/dpop_proof_stateable.rb" => [5, "legacy DPoP proof query concern"],
    "app/models/concerns/email.rb" => [6, "legacy email normalization and validation concern"],
    "app/models/concerns/identity_ceremony_candidate_record.rb" => [
      3,
      "reviewed identity ceremony candidate record concern",
    ],
    "app/models/concerns/email_ceremony_transactionable.rb" => [15, "reviewed ceremony transaction model DSL concern"],
    "app/models/concerns/flow_base.rb" => [1, "legacy flow base class attribute concern"],
    "app/models/concerns/has_birthdate.rb" => [3, "legacy birthdate validation concern"],
    "app/models/concerns/identity.rb" => [1, "legacy identity validation concern"],
    "app/models/concerns/mfa_status_trackable.rb" => [2, "legacy MFA status lifecycle concern"],
    "app/models/concerns/oauth_callback_stateable.rb" => [4, "legacy OAuth callback state query concern"],
    "app/models/concerns/occurrence.rb" => [4, "legacy occurrence validation concern"],
    "app/models/concerns/oidc_authorization_transactionable.rb" => [
      14,
      "reviewed OIDC authorization transaction DSL concern",
    ],
    "app/models/concerns/oidc_connection_record.rb" => [4, "legacy OIDC connection query concern"],
    "app/models/concerns/otp_lockable.rb" => [1, "reviewed shared OTP lifecycle concern"],
    "app/models/concerns/passkey_ceremony_transactionable.rb" => [15,
                                                                  "reviewed ceremony transaction model DSL concern",],
    "app/models/concerns/preference_resettable.rb" => [1, "legacy preference reset callback concern"],
    "app/models/concerns/public_id.rb" => [3, "legacy public id generation concern"],
    "app/models/concerns/read_only_content_entry.rb" => [9, "reviewed read-only content entry DSL concern"],
    "app/models/concerns/refresh_tokenable.rb" => [5, "legacy refresh-token lifecycle concern"],
    "app/models/concerns/retainable.rb" => [6, "legacy retention timestamp concern"],
    "app/models/concerns/secret_credential.rb" => [3, "legacy secret credential validation concern"],
    "app/models/concerns/secret_credential_ceremony_transactionable.rb" => [
      15,
      "reviewed ceremony transaction model DSL concern",
    ],
    "app/models/concerns/session_oidc_connection.rb" => [2, "legacy session OIDC connection callback"],
    "app/models/concerns/sign_flow.rb" => [16, "legacy sign flow state concern"],
    "app/models/concerns/sign_out_flow.rb" => [12, "legacy sign-out flow state concern"],
    "app/models/concerns/sign_up_flow_ticket.rb" => [8, "legacy sign-up flow ticket concern"],
    "app/models/concerns/single_use_token.rb" => [2, "legacy single-use token query concern"],
    "app/models/concerns/social_ceremony_transactionable.rb" => [16, "reviewed ceremony transaction model DSL concern"],
    "app/models/concerns/social_identifiable.rb" => [1, "legacy social identity query concern"],
    "app/models/concerns/step_up_ceremony_transactionable.rb" => [20,
                                                                  "reviewed ceremony transaction model DSL concern",],
    "app/models/concerns/telephone.rb" => [7, "legacy telephone normalization and validation concern"],
    "app/models/concerns/telephone_ceremony_transactionable.rb" => [15,
                                                                    "reviewed ceremony transaction model DSL concern",],
    "app/models/concerns/token_status_management.rb" => [4, "legacy token status query concern"],
    "app/models/concerns/totp_ceremony_transactionable.rb" => [15, "reviewed ceremony transaction model DSL concern"],
    "app/models/concerns/withdrawable.rb" => [1, "legacy withdrawal query concern"],
    "app/models/concerns/withdrawal_flow.rb" => [10, "legacy withdrawal flow state concern"],
  }.freeze

  REVIEWED_CONTROLLER_CONCERN_SIDE_EFFECTS = {
    "app/controllers/concerns/oauth_authorize_rate_limit.rb" => [
      1,
      "reviewed OAuth authorize rate-limit callback concern",
    ],
    "app/controllers/concerns/sign_oidc_logout.rb" => [1, "reviewed OIDC logout callback concern"],
    "app/controllers/concerns/sign_out_notice.rb" => [1, "reviewed sign-out notice helper concern"],
  }.freeze

  RAILS_WAY_DIRECTORY_PATTERN = %r{\Aapp/(?:services|use_cases|interactors|operations|commands|domain|application)\z}

  BRANCH_EXCEPTION_PATTERN =
    /\b(?:raise\s+(?:[A-Za-z0-9_:]+::)?(?:[A-Za-z0-9_]*(?:Required|Unauthorized|StepUp)[A-Za-z0-9_]*)(?:\b|\.new)|
          rescue_from\s+[^\n]*(?:Required|Unauthorized|StepUp))\b/x

  REVIEWED_BRANCH_EXCEPTIONS = {
    "app/controllers/concerns/acme_step_up_completion.rb" => [2, "reviewed step-up completion branch errors"],
    "app/controllers/concerns/social_auth.rb" => [13, "legacy SocialAuth control-flow errors"],
    "app/models/concerns/step_up_ceremony_transactionable.rb" => [
      4,
      "reviewed step-up ceremony transaction branch errors",
    ],
    "app/services/identity_step_up_ceremony_contract.rb" => [19, "reviewed step-up ceremony branch contract errors"],
    "app/services/identity_step_up_ceremony_freshness_committer.rb" => [6, "reviewed step-up ceremony branch errors"],
    "app/services/identity_step_up_ceremony_grant.rb" => [1, "reviewed step-up ceremony grant branch error"],
    "app/services/identity_step_up_ceremony_replay_store.rb" => [1, "reviewed step-up ceremony replay branch error"],
    "app/services/identity_step_up_ceremony_result_consumer.rb" => [6,
                                                                    "reviewed step-up ceremony result branch errors",],
    "app/services/org_registration_policy.rb" => [1, "legacy org invitation branch error"],
    "app/services/social_auth_link_handler.rb" => [1, "legacy SocialAuth link branch error"],
    "app/services/social_auth_service.rb" => [2, "legacy SocialAuth service branch errors"],
  }.freeze

  REVIEWED_RAILS_WAY_DIRECTORIES = {
    "app/services" => "legacy service layer; protocol/security boundaries remain here until migrated",
  }.freeze

  test "controller concerns do not register lifecycle side effects when included" do
    offenders = included_do_side_effect_inventory(
      "app/controllers/concerns/*.rb",
      CONTROLLER_CONCERN_SIDE_EFFECT_PATTERN,
    )

    assert_reviewed_inventory(
      REVIEWED_CONTROLLER_CONCERN_SIDE_EFFECTS,
      offenders,
      "Controller concerns must not install callbacks/helpers/rescues in included do",
    )
  end

  test "model concern included-do side effects stay in the reviewed allowlist" do
    actual = included_do_side_effect_inventory("app/models/concerns/*.rb", MODEL_CONCERN_SIDE_EFFECT_PATTERN)

    assert_reviewed_inventory(
      REVIEWED_MODEL_CONCERN_SIDE_EFFECTS,
      actual,
      "Model concern included-do side effects changed. " \
      "Move Rails DSL to the model or update this allowlist intentionally",
    )
  end

  test "Required Unauthorized and StepUp branch exceptions stay in the reviewed allowlist" do
    actual =
      Rails.root.glob("app/{controllers,models,policies,services}/**/*.rb").each_with_object({}) do |path, inventory|
        count = branch_exception_count(path)
        inventory[path.relative_path_from(Rails.root).to_s] = count if count.positive?
      end

    assert_reviewed_inventory(
      REVIEWED_BRANCH_EXCEPTIONS,
      actual,
      "Do not use Required/Unauthorized/StepUp exceptions as ordinary branches. " \
      "Use predicates plus render/redirect/return",
    )
  end

  test "Rails Way escape hatch directories stay reviewed" do
    actual =
      Rails.root.glob("app/*").select(&:directory?).filter_map do |path|
        relative = path.relative_path_from(Rails.root).to_s
        relative if relative.match?(RAILS_WAY_DIRECTORY_PATTERN)
      end.sort

    assert_equal REVIEWED_RAILS_WAY_DIRECTORIES.keys.sort, actual,
                 "Rails Way escape hatch directories changed. Add app code under controllers, models, concerns, " \
                 "policies, validators, jobs, or mailers unless a reviewed boundary requires otherwise.\n" \
                 "added: #{(actual - REVIEWED_RAILS_WAY_DIRECTORIES.keys).inspect}\n" \
                 "removed: #{(REVIEWED_RAILS_WAY_DIRECTORIES.keys - actual).inspect}"
    assert REVIEWED_RAILS_WAY_DIRECTORIES.values.all?(&:present?), "Rails Way directory allowlist entries need reasons"
  end

  private

  def included_do_side_effect_inventory(glob, pattern)
    Rails.root.glob(glob).each_with_object({}) do |path, inventory|
      count = included_do_side_effect_count(path, pattern)
      inventory[path.relative_path_from(Rails.root).to_s] = count if count.positive?
    end
  end

  def included_do_side_effect_count(path, pattern)
    included = false
    depth = 0
    count = 0

    path.readlines.each do |line|
      if line.match?(/^\s*included do\b/)
        included = true
        depth = 1
        next
      end
      next unless included

      count += 1 if line.match?(pattern)
      depth += line.scan(/\bdo\b|\{/).size
      depth -= line.scan(/\bend\b|\}/).size
      included = false if depth <= 0
    end

    count
  end

  def branch_exception_count(path)
    path.readlines.count do |line|
      next false if line.strip.start_with?("#")
      next false if line.include?("ActionPolicy::Unauthorized")

      line.match?(BRANCH_EXCEPTION_PATTERN)
    end
  end

  def assert_reviewed_inventory(expected, actual, message)
    assert expected.values.all? { |_count, reason| reason.present? }, "Allowlist entries need reasons"
    assert_equal expected.transform_values(&:first), actual,
                 "#{message}\nadded: #{(actual.keys - expected.keys).inspect}\n" \
                 "removed: #{(expected.keys - actual.keys).inspect}\nactual:\n#{format_inventory(actual)}"
  end

  def format_inventory(inventory)
    inventory.sort.map { |path, count| "#{path}: #{count}" }.join("\n")
  end
end
