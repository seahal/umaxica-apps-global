# typed: false
# frozen_string_literal: true

require "test_helper"

module ActorSupportLifecycle
  private

  def actor_support_snapshot
    preference = Actor.preferences
    cookie = preference.cookie
    actor = Actor.actor
    context = current_actor
    resource = current_resource if respond_to?(:current_resource, true)

    {
      current_actor_class: context.class.name,
      current_actor_actor_class: context.actor.class.name,
      current_actor_actor_id: context.actor.respond_to?(:id) ? context.actor.id : nil,
      current_actor_authn_null: context.authn.null?,
      current_actor_step_up_class: context.step_up.class.name,
      current_resource_class: resource&.class&.name,
      current_resource_id: resource&.id,
      actor_class: actor.class.name,
      actor_id: actor.respond_to?(:id) ? actor.id : nil,
      actor_type: Actor.actor_type.to_s,
      whoami: Actor.whoami.to_s,
      signed_in: Actor.signed_in?,
      signed_up: Actor.signed_up?,
      tld: Actor.tld.to_s,
      authentication: {
        null: Actor.authn.null?,
        login_public_id: Actor.authn.login_public_id,
        acr: Actor.authn.acr,
        amr: Actor.authn.amr,
        access_claim_sid: Actor.authn.access_claims&.dig("sid"),
        access_claim_prf: Actor.authn.access_claims&.dig("prf"),
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
        page_size: preference.page_size,
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

  def actor_policy_snapshot
    allowed = allowed_to?(:show?, current_resource, with: ActorSupportLifecyclePolicy)

    {
      allowed: allowed,
      authorization_actor_class: authorization_context[:actor].class.name,
      authorization_actor_actor_class: authorization_context[:actor].actor.class.name,
      authorization_user_class: authorization_context[:user]&.class&.name,
    }
  end
end

class ActorSupportLifecyclePolicy < ApplicationPolicy
  def show?
    actor.is_a?(Actor::Context) && record.present? && user == record
  end
end

module Acme
  module App
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      declare_authentication_mode! :open

      def show
        render json: actor_support_snapshot
      end

      def policy
        authorize!(current_resource, to: :show?, with: ActorSupportLifecyclePolicy) if current_resource.present?

        render json: actor_policy_snapshot
      end
    end
  end

  module Org
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      declare_authentication_mode! :open

      def show
        render json: actor_support_snapshot
      end

      def policy
        render json: actor_policy_snapshot
      end
    end
  end

  module Com
    class ActorSupportController < ApplicationController
      include ActorSupportLifecycle

      declare_authentication_mode! :open

      def show
        render json: actor_support_snapshot
      end

      def policy
        render json: actor_policy_snapshot
      end
    end
  end
end

class ActorSupportLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    Actor.reset
    Rails.application.routes.draw do
      get "/actor-support/acme-app", to: "acme/app/actor_support#show"
      get "/actor-support/acme-app-policy", to: "acme/app/actor_support#policy"
      get "/actor-support/acme-org", to: "acme/org/actor_support#show"
      get "/actor-support/acme-org-policy", to: "acme/org/actor_support#policy"
      get "/actor-support/acme-com", to: "acme/com/actor_support#show"
      get "/actor-support/acme-com-policy", to: "acme/com/actor_support#policy"
    end
  end

  teardown do
    Rails.application.reload_routes!
    Actor.reset
  end

  test "sign app request does not use user preference record as runtime fallback and resets afterwards" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
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
      page_size: "50",
      consented: true,
      functional: true,
      performant: true,
      targetable: false,
      consent_version: SecureRandom.uuid,
      consented_at: Time.current,
    )

    host!(host)
    get "/actor-support/acme-app", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Client", snapshot["actor_class"]
    assert_equal user.id, snapshot["actor_id"]
    assert_equal "ActorValuesContext", snapshot["current_actor_class"]
    assert_equal "Client", snapshot["current_actor_actor_class"]
    assert_equal user.id, snapshot["current_actor_actor_id"]
    assert_equal "Actor::StepUp", snapshot["current_actor_step_up_class"]
    assert_equal "Client", snapshot["current_resource_class"]
    assert_equal user.id, snapshot["current_resource_id"]
    assert_equal "client", snapshot["actor_type"]
    assert_equal "client", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "app", snapshot["tld"]
    assert_equal({ "client" => "app" }, { snapshot["whoami"] => snapshot["tld"] })
    # Hydrated from the session preference payload (default-seeded), so it is no
    # longer null. The resource ClientPreference (language "en", currency "usd")
    # must still NOT be used as a runtime fallback: language stays the session
    # default "ja" and currency "jpy".
    assert_not snapshot["preference"]["null"]
    assert_equal "ja", snapshot["preference"]["language"]
    assert_equal "jpy", snapshot["preference"]["currency"]
    assert_equal "iso", snapshot["preference"]["date_format"]
    assert_equal "24", snapshot["preference"]["time_format"]
    assert_equal "standard", snapshot["preference"]["motion"]
    assert_equal "standard", snapshot["preference"]["density"]
    assert_equal "infinity", snapshot["preference"]["page_size"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.tld
  end

  test "sign org request does not use staff preference record as runtime fallback and resets afterwards" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE)
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
      page_size: "50",
      consented: true,
      functional: true,
      performant: false,
      targetable: true,
      consent_version: SecureRandom.uuid,
      consented_at: Time.current,
    )

    host!(host)
    get "/actor-support/acme-org", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Operator", snapshot["actor_class"]
    assert_equal staff.id, snapshot["actor_id"]
    assert_equal "ActorValuesContext", snapshot["current_actor_class"]
    assert_equal "Operator", snapshot["current_actor_actor_class"]
    assert_equal staff.id, snapshot["current_actor_actor_id"]
    assert_equal "Operator", snapshot["current_resource_class"]
    assert_equal staff.id, snapshot["current_resource_id"]
    assert_equal "operator", snapshot["actor_type"]
    assert_equal "operator", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "org", snapshot["tld"]
    assert_equal({ "operator" => "org" }, { snapshot["whoami"] => snapshot["tld"] })
    # Hydrated from the session preference payload (default-seeded), so it is no
    # longer null. The resource OperatorPreference (language "en", currency "usd")
    # must still NOT be used as a runtime fallback.
    assert_not snapshot["preference"]["null"]
    assert_equal "ja", snapshot["preference"]["language"]
    assert_equal "jpy", snapshot["preference"]["currency"]
    assert_equal "iso", snapshot["preference"]["date_format"]
    assert_equal "24", snapshot["preference"]["time_format"]
    assert_equal "standard", snapshot["preference"]["motion"]
    assert_equal "standard", snapshot["preference"]["density"]
    assert_equal "infinity", snapshot["preference"]["page_size"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.tld
  end

  test "sign com request falls back to null preference when no db record or prf claim exists" do
    host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    host!(host)
    get "/actor-support/acme-com", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
    }

    assert_response :success

    snapshot = response.parsed_body

    assert_equal "Visitor", snapshot["actor_class"]
    assert_equal visitor.id, snapshot["actor_id"]
    assert_equal "ActorValuesContext", snapshot["current_actor_class"]
    assert_equal "Visitor", snapshot["current_actor_actor_class"]
    assert_equal visitor.id, snapshot["current_actor_actor_id"]
    assert_equal "Visitor", snapshot["current_resource_class"]
    assert_equal visitor.id, snapshot["current_resource_id"]
    assert_equal "visitor", snapshot["actor_type"]
    assert_equal "visitor", snapshot["whoami"]
    assert snapshot["signed_in"]
    assert snapshot["signed_up"]
    assert_equal "com", snapshot["tld"]
    assert_equal({ "visitor" => "com" }, { snapshot["whoami"] => snapshot["tld"] })
    assert_predicate snapshot["preference"], :present?
    # No resource preference record exists, but the session preference payload is
    # default-seeded, so Actor.preferences hydrates to non-null defaults.
    assert_not snapshot["preference"]["null"]
    assert_equal "ja", snapshot["preference"]["language"]
    assert_equal "jpy", snapshot["preference"]["currency"]
    assert_equal "iso", snapshot["preference"]["date_format"]
    assert_equal "24", snapshot["preference"]["time_format"]
    assert_equal "standard", snapshot["preference"]["motion"]
    assert_equal "standard", snapshot["preference"]["density"]
    assert_equal "infinity", snapshot["preference"]["page_size"]

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.tld
  end

  test "unauthenticated request exposes unauthenticated current_actor context" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    host!(host)
    get "/actor-support/acme-app", params: { ri: "jp" }

    assert_response :success
    snapshot = response.parsed_body

    assert_equal "ActorValuesContext", snapshot["current_actor_class"]
    assert_equal Unauthenticated.instance.class.name, snapshot["current_actor_actor_class"]
    assert snapshot["current_actor_authn_null"]
    assert_nil snapshot["current_resource_class"]
    assert_equal "unauthenticated", snapshot["actor_type"]
    assert_not snapshot["signed_in"]
  end

  test "action policy receives current_actor context for authenticated app request" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: SecureRandom.hex(10),
      created_at: Time.current,
      updated_at: Time.current,
    )

    host!(host)
    get "/actor-support/acme-app-policy", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
    }

    assert_response :success
    snapshot = response.parsed_body

    assert snapshot["allowed"]
    assert_equal "ActorValuesContext", snapshot["authorization_actor_class"]
    assert_equal "Client", snapshot["authorization_actor_actor_class"]
    assert_equal "Client", snapshot["authorization_user_class"]
  end

  test "sequential app and org requests rebuild actor context without cross surface leakage" do
    app_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    org_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: SecureRandom.hex(10),
      created_at: Time.current,
      updated_at: Time.current,
    )
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE)

    host!(app_host)
    get "/actor-support/acme-app", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-USER" => user.id.to_s,
    }

    assert_response :success
    app_snapshot = response.parsed_body

    assert_equal "Client", app_snapshot["actor_class"]
    assert_equal user.id, app_snapshot["actor_id"]
    assert_equal "client", app_snapshot["actor_type"]
    assert_equal "app", app_snapshot["tld"]
    assert_equal Unauthenticated.instance, Actor.actor
    assert_nil Actor.tld

    host!(org_host)
    get "/actor-support/acme-org", params: { ri: "jp" }, headers: {
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
    }

    assert_response :success
    org_snapshot = response.parsed_body

    assert_equal "Operator", org_snapshot["actor_class"]
    assert_equal staff.id, org_snapshot["actor_id"]
    assert_equal "operator", org_snapshot["actor_type"]
    assert_equal "org", org_snapshot["tld"]
    assert_not_equal app_snapshot["actor_type"], org_snapshot["actor_type"]
    assert_not_equal app_snapshot["tld"], org_snapshot["tld"]
    assert_equal Unauthenticated.instance, Actor.actor
    assert_nil Actor.tld
  end

  test "action policy fails closed for unauthenticated app request" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    host!(host)
    get "/actor-support/acme-app-policy", params: { ri: "jp" }

    assert_response :success

    snapshot = response.parsed_body

    assert_not snapshot["allowed"]
    assert_equal "ActorValuesContext", snapshot["authorization_actor_class"]
    assert_equal Unauthenticated.instance.class.name, snapshot["authorization_actor_actor_class"]
    assert_nil snapshot["authorization_user_class"]
  end
end
