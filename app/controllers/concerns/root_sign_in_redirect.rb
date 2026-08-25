# typed: false
# frozen_string_literal: true

# Permanently redirects a credential gateway root request that carries an allowlisted `ri` to the
# sign-in entry point on the same host, keeping the region on the destination.
#
# This is a same-host entry-point canonicalization, which is why it is separate from
# `RegionalRootRedirect`: that concern sends a request to a different hostname and deliberately
# drops the request context, while this one stays on the host and must preserve it.
#
# The declaration prepends the callback so it runs ahead of preference transport and actor
# hydration -- the response is a static redirect built from a route helper, so none of those side
# effects are needed. It also runs ahead of `PreferenceGlobal#set_region`, so a missing or
# unrecognized `ri` falls through to that existing normalization instead of being canonicalized
# here. `ensure_fqdn_gate_first!` restores the availability switch to the front of the chain,
# because a surface that is switched off must not answer at all, not even with a redirect.
module RootSignInRedirect
  extend ActiveSupport::Concern

  class_methods do
    # @yieldparam region [String] the validated region, one of `RequestContextContract::ALLOWED_REGIONS`
    # @yieldreturn [String] the sign-in path for this surface, carrying the region
    def redirect_root_to_sign_in(&path_builder)
      raise ArgumentError, "redirect_root_to_sign_in requires a path builder block" unless path_builder

      define_method(:root_sign_in_redirect_path, &path_builder)
      private(:root_sign_in_redirect_path)
      prepend_before_action(:redirect_root_to_sign_in)
      ensure_fqdn_gate_first!
    end
  end

  private

  def redirect_root_to_sign_in
    return unless request.get? || request.head?

    region = params[:ri].to_s
    return unless RequestContextContract::ALLOWED_REGIONS.include?(region)

    redirect_to(root_sign_in_redirect_path(region), status: :moved_permanently)
  end
end
