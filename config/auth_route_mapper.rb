# typed: false
# frozen_string_literal: true

# Route mapper extensions for the Auth credential gateway.
#
# These macros let `config/routes/auth.rb` read as a surface contract table:
# the surface route groups stay declarative while the protocol/public fixed
# paths and the shared RP-OIDC and social wiring live here. Anything that
# would otherwise force a `path:`, `as:`, or `to:` literal into the surface
# body is isolated in this file.
#
# Loaded via `require_relative` + `include` from `config/routes.rb`, NOT as an
# initializer. As an initializer this used to load in alphabetical order
# (`auth_*` sorts late), so any earlier initializer that touched the route set
# evaluated `config/routes/auth.rb` before `auth_routes` existed and crashed
# boot with `NoMethodError: undefined method 'auth_routes'`. Requiring it from
# routes.rb guarantees the macros are defined immediately before the surface
# tables that use them, independent of initializer order. Lives under `config/`
# (not `lib/`) so Zeitwerk does not also try to manage the constant.
module AuthRouteMapper
  # Wrap every Auth surface under the shared `auth` module/name scope.
  def auth_routes(&)
    scope(module: :auth, as: :auth, &)
  end

  # One credential-gateway host surface (app/com/org). Inside the block the
  # mapper is already scoped to the surface controller module and name.
  def auth_surface(surface, host:, &)
    constraints(host: Array(host).compact) do
      scope(module: surface, as: surface, &)
    end
  end

  # Protocol/public fixed-path endpoints shared by every Auth surface.
  #
  # The fixed suffixes (`.well-known/jwks.json`, `robots.txt`, `sitemap.xml`,
  # `csp-violation-report`) are contractual: browsers and crawlers cache the
  # exact path, so they must never change. They are isolated here so the
  # surface route groups stay free of `path:` literals.
  def auth_public_gateway_routes
    namespace(:well_known, path: ".well-known") do
      resource(:jwks, only: :show, path: "jwks.json", format: false)
    end

    resource(:health, only: :show)
    namespace(:health) do
      resource(:liveness, only: :show)
      resource(:readiness, only: :show)
      resource(:startup, only: :show)
    end

    resources(:robots, only: :index, path: "robots.txt")
    resource(:sitemap, only: :show, path: "sitemap.xml")
    resource(:csp_violation_report, only: :create, path: "csp-violation-report")
  end

  # RP OIDC endpoints. The controllers live under the matching `oidc`
  # controller namespace (`Auth::<Surface>::Oidc::*`), so these routes need
  # no `to:` indirection. Identical across all three surfaces.
  def auth_rp_oidc_routes
    namespace(:oidc) do
      # RP login start: redirects to the Acme Authorization Server.
      resource(:authorization, only: :show)
      # RP callback from the Acme Authorization Server.
      resource(:callback, only: :show)

      # RP back-channel logout receiver.
      namespace(:backchannel) do
        resource(:logout, only: :create)
      end
    end
  end

  # App-only social login wiring (Google/Apple).
  #
  # The OmniAuth callback and entry routes intentionally keep `to:` and
  # `defaults:`: the callback CSRF verification in `SocialOmniauthCallbackFlow`
  # keys on `action_name == "omniauth"` (Apple relies on this to accept its
  # cross-site form_post), so renaming the action to a RESTful `show` would
  # require re-keying a shared security concern. That trade-off was declined,
  # so the wiring is preserved verbatim and isolated here, out of the surface
  # body. The connection-lifecycle routes below carry no such constraint.
  def auth_app_social_routes
    namespace(:social) do
      # OmniAuth provider callbacks. Provider is injected via route defaults
      # and the action stays `omniauth` for the CSRF reason documented above.
      get(
        "google/callback",
        to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
        as: :google_callback,
        defaults: { provider: "google" },
      )

      match(
        "apple/callback",
        to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
        via: %i(get post),
        as: :apple_callback,
        defaults: { provider: "apple" },
      )

      get(
        "failure",
        to: "/auth/app/omniauth/omniauth_callbacks#failure",
      )

      # Provider sign-in / sign-up entry points into the OmniAuth flow.
      scope :google do
        get(
          "sign/in", to: "/auth/app/social/authentications#continue", as: :google_auth_in,
                     defaults: { provider: "google", intent: "login" },
        )
        get(
          "sign/up", to: "/auth/app/social/authentications#continue", as: :google_auth_up,
                     defaults: { provider: "google", intent: "login", entry: "auth_up" },
        )
      end

      scope :apple do
        get(
          "sign/in", to: "/auth/app/social/authentications#continue", as: :apple_auth_in,
                     defaults: { provider: "apple", intent: "login" },
        )
        get(
          "sign/up", to: "/auth/app/social/authentications#continue", as: :apple_auth_up,
                     defaults: { provider: "apple", intent: "login", entry: "auth_up" },
        )
      end
    end
  end

  # Shared sign-up checkpoint routes for app/com.
  #
  # Each checkpoint owns its own destroy action so cancellation is expressed
  # on the current step URL instead of a separate `cancellation` resource.
  def auth_signup_check_routes(providers: %i(apple google email telephone))
    namespace(:up) do
      resource(:email, only: %i(new create))
      resource(:telephone, only: %i(new create))

      namespace(:guard) do
        resource(:apple, only: :show)
        resource(:google, only: :show)
        resource(:email, only: :show)
        resource(:telephone, only: :show)
      end

      namespace(:check) do
        auth_signup_check_provider_routes(providers:)
      end
    end
  end

  def auth_signup_check_provider_routes(providers:)
    if providers.include?(:apple)
      namespace(:apple) do
        resource(:confirmation, only: %i(show update destroy))
        resource(:birthdate, only: %i(show update destroy))
      end
    end

    if providers.include?(:google)
      namespace(:google) do
        resource(:confirmation, only: %i(show update destroy))
        resource(:birthdate, only: %i(show update destroy))
      end
    end

    if providers.include?(:email)
      namespace(:email) do
        resource(:otp, only: %i(show create update destroy))
        resource(:birthdate, only: %i(show update destroy))
      end
    end

    return unless providers.include?(:telephone)

    namespace(:telephone) do
      resource(:otp, only: %i(show create update destroy))
      resource(:passkey, only: %i(show create update destroy))
      resource(:passcode, only: %i(show update destroy))
      resource(:birthdate, only: %i(show update destroy))
    end

  end
end
