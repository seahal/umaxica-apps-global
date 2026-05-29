# frozen_string_literal: true

require "json"

module Jit
  module LogEvent
    module_function

    def format(name, payload = nil, **attributes)
      {
        event: name,
        data: normalize_payload(payload, attributes),
      }.compact.to_json
    end

    def normalize_payload(payload, attributes)
      data =
        case payload
        when nil
          {}
        when Hash
          payload
        else
          { message: payload }
        end

      data.merge(attributes).transform_values { |value| normalize_value(value) }.compact
    end

    def normalize_value(value)
      case value
      when Exception
        { class: value.class.name, message: value.message }
      else
        value
      end
    end
  end
end
