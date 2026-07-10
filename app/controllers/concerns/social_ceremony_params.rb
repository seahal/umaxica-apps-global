# typed: false
# frozen_string_literal: true

# Shared param readers for the Base-side social ceremony endpoints
# (Social::Authentication::ContinuationsController / CompletionsController).
module SocialCeremonyParams
  extend ActiveSupport::Concern

  private

  def social_provider_param
    provider = params[:id].to_s
    return provider if IdentitySocialCeremonyContract::PROVIDERS.include?(provider)

    raise ActionController::BadRequest, "invalid social provider"
  end

  def social_entry_param
    (params[:entry].to_s == "sign_up") ? "sign_up" : "sign_in"
  end

  def safe_social_return_to(value)
    return nil if value.blank?

    path_from_signed_pt(signed_pt_token(value))
  end
end
