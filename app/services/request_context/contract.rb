# typed: false
# frozen_string_literal: true

module RequestContext
  module Contract
    REQUIRED_KEYS = %i(ri).freeze
    RETURN_TARGET_KEYS = %i(pt nt xt).freeze
    OPTIONAL_OVERLAY_KEYS = %i(lx ct tz cu df tf mo dn pp).freeze
    PUBLIC_KEYS = (REQUIRED_KEYS + RETURN_TARGET_KEYS + OPTIONAL_OVERLAY_KEYS).freeze
    ALLOWED_REGIONS = %w(jp us).freeze
    DEFAULT_REGION = "jp"

    INTERNAL_NAMES = {
      ri: :region,
      pt: :path_target,
      nt: :navigation_target,
      xt: :external_target,
      lx: :language,
      ct: :theme,
      tz: :timezone,
      cu: :currency,
      df: :date_format,
      tf: :time_format,
      mo: :motion,
      dn: :density,
      pp: :items_per_page,
    }.freeze

    FAMILIES = {
      ri: :required,
      pt: :path_target,
      nt: :navigation_target,
      xt: :external_target,
      lx: :optional_overlay,
      ct: :optional_overlay,
      tz: :optional_overlay,
      cu: :optional_overlay,
      df: :optional_overlay,
      tf: :optional_overlay,
      mo: :optional_overlay,
      dn: :optional_overlay,
      pp: :optional_overlay,
    }.freeze

    module_function

    def public_keys = PUBLIC_KEYS

    def required_keys = REQUIRED_KEYS

    def redirect_target_keys = RETURN_TARGET_KEYS

    def optional_overlay_keys = OPTIONAL_OVERLAY_KEYS

    def allowed_regions = ALLOWED_REGIONS

    def default_region = DEFAULT_REGION

    def internal_names = INTERNAL_NAMES

    def internal_name(key)
      INTERNAL_NAMES.fetch(key.to_sym)
    end

    def family(key)
      FAMILIES.fetch(key.to_sym)
    end

    def redirect_target_key?(key)
      RETURN_TARGET_KEYS.include?(key.to_sym)
    end

    def normalize(key, value)
      return value.to_s if redirect_target_key?(key)
      return value.to_s if key.to_sym == :tz

      value.to_s.downcase
    end

    def normalize_region(value)
      normalized = normalize(:ri, value)
      ALLOWED_REGIONS.include?(normalized) ? normalized : DEFAULT_REGION
    end
  end
end
