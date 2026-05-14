# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/visitor_helpers"

module CurrentSupportLifecycle
  private

  def current_support_snapshot
    preference = Actor.preference
    cookie = preference.cookie
    actor = Actor.actor

    {
      actor_class: actor.class.name,
      actor_id: actor.respond_to?(:id) ? actor.id : nil,
      actor_type: Actor.actor_type.to_s,
      domain: Actor.domain.to_s,
      session: Actor.session,
      token_sid: Actor.token&.dig("sid"),
      token_prf: Actor.token&.dig("prf"),
      preference: {
        null: preference.null?,
        language: preference.language,
        region: preference.region,
        timezone: preference.timezone,
        theme: preference.theme,
        cookie: {
          consented: cookie.consented?,
          functional: cookie.functional?,
          performant: cookie.performant?,
          targetable: cookie.targetable?,
          consent_version: cookie.consent_version,
          consented_at: cookie.consented_at&.to_s,
        },
      },
    }
  end
end

module Apex
  module App
    class CurrentSupportController < ApplicationController
      include CurrentSupportLifecycle

      def show
        render json: current_support_snapshot
      end
    end
  end

  module Org
    class CurrentSupportController < ApplicationController
      include CurrentSupportLifecycle

      def show
        render json: current_support_snapshot
      end
    end
  end

  module Com
    class CurrentSupportController < ApplicationController
      include CurrentSupportLifecycle

      def show
        render json: current_support_snapshot
      end
    end
  end
end

class CurrentSupportLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    Actor.reset
    Rails.application.routes.draw do
      get "/current-support/apex-app", to: "apex/app/current_support#show"
      get "/current-support/apex-org", to: "apex/org/current_support#show"
      get "/current-support/apex-com", to: "apex/com/current_support#show"
    end
  end

  teardown do
    Rails.application.reload_routes!
    Actor.reset
  end

  test "sign app request resolves current from user preference record and resets afterwards" do
    host = ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
    user = User.create!(
      status_id: UserStatus::ACTIVE,
      public_id: SecureRandom.hex(10),
      created_at: Time.current,
      updated_at: Time.current,
    )
    UserPreference.create!(
      user: user,
      language: "en",
      region: "us",
      timezone: "America/New_York",
      theme: "dr",
      consented: true,
      functional: true,
      performant: true,
      targetable: false,
      consent_version: SecureRandom.uuid,
      consented_at: Time.current,
    )

    host!(host)
    get "/current-support/apex-app", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "User", snapshot["actor_class"]
    assert_equal user.id, snapshot["actor_id"]
    assert_equal "user", snapshot["actor_type"]
    assert_equal "app", snapshot["domain"]
    assert_not snapshot["preference"]["null"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_nil Actor.domain
  end

  test "sign org request resolves current from staff preference record and resets afterwards" do
    host = ENV.fetch("APEX_STAFF_URL", "www.org.localhost")
    staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE)
    OperatorPreference.create!(
      staff: staff,
      language: "en",
      region: "us",
      timezone: "America/New_York",
      theme: "dr",
      consented: true,
      functional: true,
      performant: false,
      targetable: true,
      consent_version: SecureRandom.uuid,
      consented_at: Time.current,
    )

    host!(host)
    get "/current-support/apex-org", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Operator", snapshot["actor_class"]
    assert_equal staff.id, snapshot["actor_id"]
    assert_equal "operator", snapshot["actor_type"]
    assert_equal "org", snapshot["domain"]
    assert_not snapshot["preference"]["null"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_nil Actor.domain
  end

  test "sign com request falls back to null preference when no db record or prf claim exists" do
    host = ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    host!(host)
    get "/current-support/apex-com", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Visitor", snapshot["actor_class"]
    assert_equal visitor.id, snapshot["actor_id"]
    assert_equal "visitor", snapshot["actor_type"]
    assert_equal "com", snapshot["domain"]
    assert_predicate snapshot["preference"], :present?
    assert snapshot["preference"]["null"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_nil Actor.domain
  end
end
