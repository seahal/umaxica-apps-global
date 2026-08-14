# typed: false
# frozen_string_literal: true

# Permanently redirects a `www` gateway root request that carries an allowlisted `ri` to the
# canonical regional root for the same surface.
#
# The declaration prepends the callback so it runs ahead of preference transport, actor hydration,
# and the rest of the surface lifecycle. That placement is deliberate: the response is a static,
# allowlist-derived 301 that reads no database row and mints no preference cookie, so none of those
# side effects should be paid for a request whose response the browser discards. It also places the
# canonicalization ahead of `PreferenceGlobal#set_region`, which normalizes a missing or
# unrecognized `ri` to the default region -- a request this concern deliberately does not act on
# keeps that existing behavior untouched.
#
# `ensure_fqdn_gate_first!` restores the availability switch to the front of the chain afterwards,
# because a surface that is switched off must not answer at all, not even with a redirect.
module RegionalRootRedirect
  extend ActiveSupport::Concern

  class_methods do
    # @param surface [Symbol] the declaring controller's surface, one of `RegionalRootUrlRegistry::SURFACES`
    def redirect_root_to_regional_host(surface:)
      unless RegionalRootUrlRegistry::SURFACES.include?(surface)
        raise ArgumentError, "unknown regional redirect surface: #{surface.inspect}"
      end

      define_method(:regional_root_redirect_surface) { surface }
      private(:regional_root_redirect_surface)
      prepend_before_action(:redirect_to_regional_root)
      ensure_fqdn_gate_first!
    end
  end

  private

  def redirect_to_regional_root
    return unless request.get? || request.head?

    url = RegionalRootUrlRegistry.url_for(surface: regional_root_redirect_surface, region: params[:ri])
    return if url.nil?

    redirect_to(url, status: :moved_permanently, allow_other_host: cross_host_redirect_allowed?)
  end
end
