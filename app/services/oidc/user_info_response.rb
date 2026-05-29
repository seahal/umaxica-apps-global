# typed: false
# frozen_string_literal: true

module Oidc
  module UserInfoResponse
    module_function

    def build(resource:, payload:)
      resource_type = payload.fetch("act")
      claims = {
        sub: Oidc::Subject.for(resource, resource_type: resource_type),
        acr: payload["acr"],
        amr: payload["amr"],
        auth_time: payload["auth_time"],
      }.compact

      attach_profile_claims(claims, resource)
      claims
    end

    def attach_profile_claims(claims, resource)
      claims[:name] = resource.name if resource.respond_to?(:name) && resource.name.present?
      claims[:email] = resource.email if resource.respond_to?(:email) && resource.email.present?
      claims[:email_verified] = true if claims[:email].present?
    end
  end
end
