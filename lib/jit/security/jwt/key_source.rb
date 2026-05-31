# typed: false
# frozen_string_literal: true

module Jit
  module Security
    module Jwt
      class KeySource
        def initialize(env: ENV, credentials: Rails.app.creds)
          @env = env
          @credentials = credentials
        end

        def fetch(name, default = nil)
          @env.fetch(name.to_s, default)
        end

        def value(name)
          @env[name.to_s].presence || @credentials.option(name)
        end

        def csv(name)
          split_csv(@env[name.to_s])
        end

        private

        def split_csv(value)
          list = value.to_s.split(",").map(&:strip)
          list.reject!(&:empty?)
          list.freeze
        end
      end
    end
  end
end
