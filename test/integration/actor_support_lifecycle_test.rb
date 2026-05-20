# typed: false
# frozen_string_literal: true

require "test_helper"

module ActorSupportLifecycle
  private

  def actor_support_snapshot
    preference = Actor.preference
    cookie = preference.cookie
    actor = Actor.actor

    {
      actor_class: actor.class.name,
      actor_id: actor.respond_to?(:id) ? actor.id : nil,
      actor_type: Actor.actor_type.to_s,
      whoami: Actor.whoami.to_s,
      signed_in: Actor.signed_in?,
      signed_up: Actor.signed_up?,
      tld: Actor.tld.to_s,
      session: Actor.session,
      token_sid: Actor.token&.dig("sid"),
      token_prf: Actor.token&.dig("prf"),
      authentication: {
        null: Actor.authentication.null?,
        login_public_id: Actor.authentication.login_public_id,
        acr: Actor.authentication.acr,
        amr: Actor.authentication.amr,
      },
      preference: {
        null: preference.null?,
        language: preference.language,
        region: preference.region,
        timezone: preference.timezone,
        theme: preference.theme,
        currency: preference.currency,
        date_format: preference.date_format,
        time_format: preference.time_format,
        motion: preference.motion,
        density: preference.density,
        items_per_page: preference.items_per_page,
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
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      def show
        render json: actor_support_snapshot
      end
    end
  end

  module Org
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      def show
        render json: actor_support_snapshot
      end
    end
  end

  module Com
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      def show
        render json: actor_support_snapshot
      end
    end
  end
end

class ActorSupportLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    Actor.reset
    Rails.application.routes.draw do
      get "/actor-support/apex-app", to: "apex/app/actor_support#show"
      get "/actor-support/apex-org", to: "apex/org/actor_support#show"
      get "/actor-support/apex-com", to: "apex/com/actor_support#show"
    end
  end

  teardown do
    Rails.application.reload_routes!
    Actor.reset
  end

  test "sign app request resolves current from user preference record and resets afterwards" do
    host = ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
    user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: SecureRandom.hex(10),
      created_at: Time.current,
      updated_at: Time.current,
    )
    ClientPreference.create!(
      user: user,
      language: "en",
      region: "us",
      timezone: "America/New_York",
      theme: "dr",
      currency: "usd",
      date_format: "mdy",
      time_format: "hour_12",
      motion: "reduced",
      density: "compact",
      items_per_page: "50",
      consented: true,
      functional: true,
      performant: true,
      targetable: false,
      consent_version: SecureRandom.uuid,
      consented_at: Time.current,
    )

    host!(host)
    get "/actor-support/apex-app", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Client", snapshot["actor_class"]
    assert_equal user.id, snapshot["actor_id"]
    assert_equal "client", snapshot["actor_type"]
    assert_equal "client", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "app", snapshot["tld"]
    assert_equal({ "client" => "app" }, { snapshot["whoami"] => snapshot["tld"] })
    assert_not snapshot["preference"]["null"]
    assert_equal "usd", snapshot["preference"]["currency"]
    assert_equal "mdy", snapshot["preference"]["date_format"]
    assert_equal "hour_12", snapshot["preference"]["time_format"]
    assert_equal "reduced", snapshot["preference"]["motion"]
    assert_equal "compact", snapshot["preference"]["density"]
    assert_equal "50", snapshot["preference"]["items_per_page"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Authentication::NULL, Actor.authentication
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_nil Actor.tld
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
      currency: "usd",
      date_format: "mdy",
      time_format: "hour_12",
      motion: "reduced",
      density: "compact",
      items_per_page: "50",
      consented: true,
      functional: true,
      performant: false,
      targetable: true,
      consent_version: SecureRandom.uuid,
      consented_at: Time.current,
    )

    host!(host)
    get "/actor-support/apex-org", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Operator", snapshot["actor_class"]
    assert_equal staff.id, snapshot["actor_id"]
    assert_equal "operator", snapshot["actor_type"]
    assert_equal "operator", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "org", snapshot["tld"]
    assert_equal({ "operator" => "org" }, { snapshot["whoami"] => snapshot["tld"] })
    assert_not snapshot["preference"]["null"]
    assert_equal "usd", snapshot["preference"]["currency"]
    assert_equal "mdy", snapshot["preference"]["date_format"]
    assert_equal "hour_12", snapshot["preference"]["time_format"]
    assert_equal "reduced", snapshot["preference"]["motion"]
    assert_equal "compact", snapshot["preference"]["density"]
    assert_equal "50", snapshot["preference"]["items_per_page"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Authentication::NULL, Actor.authentication
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_nil Actor.tld
  end

  test "sign com request falls back to null preference when no db record or prf claim exists" do
    host = ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    host!(host)
    get "/actor-support/apex-com", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Visitor", snapshot["actor_class"]
    assert_equal visitor.id, snapshot["actor_id"]
    assert_equal "visitor", snapshot["actor_type"]
    assert_equal "visitor", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "com", snapshot["tld"]
    assert_equal({ "visitor" => "com" }, { snapshot["whoami"] => snapshot["tld"] })
    assert_predicate snapshot["preference"], :present?
    assert snapshot["preference"]["null"]
    assert_equal "jpy", snapshot["preference"]["currency"]
    assert_equal "iso", snapshot["preference"]["date_format"]
    assert_equal "hour_24", snapshot["preference"]["time_format"]
    assert_equal "standard", snapshot["preference"]["motion"]
    assert_equal "standard", snapshot["preference"]["density"]
    assert_equal "20", snapshot["preference"]["items_per_page"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Authentication::NULL, Actor.authentication
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preference
    assert_nil Actor.tld
  end
end
