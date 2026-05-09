# typed: false
# frozen_string_literal: true

# FIXME: Find out why this file exists.
class Current
  # Immutable value object representing the resolved preference state for the current request.
  #
  # Use `Current.preference` to access -- never nil, returns NULL for guests/bearer tokens.
  #
  # Examples:
  #   Current.preference.language   # => "ja"
  #   Current.preference.timezone   # => "Asia/Tokyo"
  #   Current.preference.theme      # => "sy"
  #   Current.preference.cookie.consented?  # => false
  #   Current.preference.null?      # => true (for guests)
  class Preference
    attr_reader :language, :region, :timezone, :theme

    Cookie =
      Data.define(:consented, :functional, :performant, :targetable, :consent_version, :consented_at) do
        def consented? = !!consented

        def functional? = !!functional

        def performant? = !!performant

        def targetable? = !!targetable
      end

    DEFAULTS = {
      language: "ja",
      region: "jp",
      timezone: "Asia/Tokyo",
      theme: "sy",
    }.freeze

    NULL_COOKIE = Cookie.new(
      consented: false,
      functional: false,
      performant: false,
      targetable: false,
      consent_version: nil,
      consented_at: nil,
    ).freeze

    def initialize(language: DEFAULTS[:language], region: DEFAULTS[:region],
                   timezone: DEFAULTS[:timezone], theme: DEFAULTS[:theme],
                   cookie: NULL_COOKIE, null: false)
      @language = language.freeze
      @region = region.freeze
      @timezone = timezone.freeze
      @theme = theme.freeze
      @cookie = cookie
      @null = null
      freeze
    end

    def cookie
      @cookie
    end

    def null?
      @null
    end

    def locale
      case @language
      when "ja" then :ja
      when "en" then :en
      else :"#{@language}"
      end
    end

    def time_zone
      ActiveSupport::TimeZone[@timezone] || ActiveSupport::TimeZone["Asia/Tokyo"]
    end

    def dark_mode?
      @theme == "dr"
    end

    def light_mode?
      @theme == "li"
    end

    def system_theme?
      @theme == "sy"
    end

    def to_h
      {
        language: @language,
        region: @region,
        timezone: @timezone,
        theme: @theme,
        consented: @cookie.consented?,
      }
    end

    def with_cookie(cookie)
      self.class.new(
        language: @language,
        region: @region,
        timezone: @timezone,
        theme: @theme,
        cookie: self.class.cookie_from(cookie),
        null: @null,
      )
    end

    # Null Object -- returned when no preference is loaded (guests, bearer tokens).
    # All values are safe defaults; no DB access occurs.
    NULL = new(null: true).freeze

    # Build Preference from JWT prf claim hash
    # @param prf_claim [Hash] the prf claim from JWT payload with lx, ri, tz, ct keys
    # @param cookie [Cookie] optional cookie consent data
    # @return [Preference] the constructed preference, or NULL if claim is invalid
    def self.from_jwt(prf_claim, cookie: NULL_COOKIE)
      return NULL unless prf_claim.is_a?(Hash)

      new(
        language: prf_claim["lx"] || DEFAULTS[:language],
        region: prf_claim["ri"] || DEFAULTS[:region],
        timezone: prf_claim["tz"] || DEFAULTS[:timezone],
        theme: prf_claim["ct"] || DEFAULTS[:theme],
        cookie: cookie,
      )
    end

    def self.cookie_from(value)
      case value
      when Cookie
        value
      when Hash
        build_cookie_from_hash(value)
      else
        build_cookie_from_object(value)
      end
    end

    def self.build_cookie_from_hash(value)
      Cookie.new(
        consented: value.key?(:consented) ? value[:consented] : value["consented"],
        functional: value.key?(:functional) ? value[:functional] : value["functional"],
        performant: value.key?(:performant) ? value[:performant] : value["performant"],
        targetable: value.key?(:targetable) ? value[:targetable] : value["targetable"],
        consent_version: value.key?(:consent_version) ? value[:consent_version] : value["consent_version"],
        consented_at: value.key?(:consented_at) ? value[:consented_at] : value["consented_at"],
      )
    end
    private_class_method :build_cookie_from_hash

    def self.build_cookie_from_object(value)
      return NULL_COOKIE if value.blank?

      Cookie.new(
        consented: value.try(:consented),
        functional: value.try(:functional),
        performant: value.try(:performant),
        targetable: value.try(:targetable),
        consent_version: value.try(:consent_version),
        consented_at: value.try(:consented_at),
      )
    end
    private_class_method :build_cookie_from_object
  end
end
