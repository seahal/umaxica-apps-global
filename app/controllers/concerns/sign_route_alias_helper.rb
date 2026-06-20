# typed: false
# frozen_string_literal: true

module SignRouteAliasHelper
  extend ActiveSupport::Concern

  private

  def method_missing(name, *, **kwargs, &)
    helper_name = name.to_s
    return super unless helper_name.start_with?("acme_")

    target_name = helper_name.sub(/\Aacme_/, "sign_")
    return super unless respond_to?(target_name, true)

    if helper_name.end_with?("_url") && respond_to?(:acme_authority_host, true)
      kwargs[:host] ||= acme_authority_host
    end
    public_send(target_name, *, **kwargs, &)
  end

  def respond_to_missing?(name, include_private = false)
    helper_name = name.to_s
    helper_name.start_with?("acme_") || super
  end
end

Rails.application.routes.url_helpers.include(SignRouteAliasHelper)
