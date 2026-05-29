# typed: false
# frozen_string_literal: true

module Jit
  module HostOriginEnv
    module_function

    def trusted_origins(*hosts)
      hosts.flatten.compact_blank.flat_map { |host| origins_for(host) }.uniq
    end

    def origins_for(host)
      raw = host.to_s.strip
      return [] if raw.blank?
      return [raw] if raw.match?(%r{\Ahttps?://})

      return ["https://#{raw}"] if Rails.env.production?

      ["http://#{raw}", "https://#{raw}"]
    end
  end
end
