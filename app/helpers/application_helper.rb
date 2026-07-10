# typed: false
# frozen_string_literal: true

module ApplicationHelper
  # Authentication helpers are provided by AuthenticationClient and AuthenticationOperator concerns
  # No need to define them here - they're already available via helper_method

  EDGE_HOST_ENV_KEYS = {
    app: %w(PUBLIC_EDGE_SERVICE_URL EDGE_SERVICE_URL),
    org: %w(PUBLIC_EDGE_STAFF_URL EDGE_STAFF_URL),
    com: %w(PUBLIC_EDGE_CORPORATE_URL EDGE_CORPORATE_URL),
  }.freeze

  def page_title(title = nil)
    if title.present?
      content_for(:page_title, title)
      title
    else
      content_for(:page_title) || t("meta.default_title")
    end
  end

  def theme_cookie_value
    # Support both symbol and string access, and handle nil
    # Fallback to request.cookies when helper cookies are empty.
    raw = (
      cookies[:ct] ||
        cookies["ct"] ||
        request.cookies["ct"]
    ).to_s.downcase
    {
      "dr" => "dark",
      "dark" => "dark",
      "li" => "light",
      "light" => "light",
      "sy" => "system",
      "system" => "system",
    }[raw] || "system"
  end

  def theme_html_class
    theme = theme_cookie_value
    classes = ["theme-#{theme}"]
    classes << "dark" if theme == "dark"
    classes.join(" ")
  end

  # Backward-compatible name used by some layouts.
  def theme_class
    theme_html_class
  end

  def current_banner_for(tld:, region:, domain:)
    region = :ww if region&.to_sym == :global
    validate_banner_args!(tld: tld, region: region, domain: domain)

    banner_model = banner_model_for(tld)
    return if banner_model.blank?

    connection_owner = banner_connection_owner_for(banner_model)
    return banner_model.current.first if connection_owner.blank?

    operation =
      lambda do
        connection_owner.connected_to(role: :writing) do
          banner_model.current.first
        end
      end
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::DatabaseConnectionError
    nil
  end

  def edge_host
    surface = request.respond_to?(:host) ? CoreSurface.current(request) : CoreSurface::DEFAULT
    env_key = EDGE_HOST_ENV_KEYS.fetch(surface, EDGE_HOST_ENV_KEYS.fetch(CoreSurface::DEFAULT))

    CoreHostNormalization.normalize(ENV.fetch(env_key.first))
  end

  private

  def validate_banner_args!(tld:, region:, domain:)
    allowed_tlds = %i(app org com)
    allowed_domains = %i(sign core acme docs news help)

    raise ArgumentError, "Invalid tld: #{tld}" unless allowed_tlds.include?(tld&.to_sym)
    raise ArgumentError, "Invalid domain: #{domain}" unless allowed_domains.include?(domain&.to_sym)

    allowed_regions =
      case domain.to_sym
      when :sign, :acme then [:ww]
      else [:jp, :us]
      end

    raise ArgumentError,
          "Invalid region: #{region} for domain: #{domain}" unless allowed_regions.include?(region&.to_sym)
  end

  def banner_model_for(tld)
    case tld.to_sym
    when :app
      ClientBanner
    when :org
      OperatorBanner
    when :com
      VisitorBanner
    end
  end

  def banner_connection_owner_for(banner_model)
    banner_model.ancestors.find do |ancestor|
      ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class?
    end
  end
end
