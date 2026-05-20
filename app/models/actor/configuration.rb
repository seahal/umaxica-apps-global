# typed: false
# frozen_string_literal: true

class Actor
  class Configuration
    class NullValue
      def nil? = true

      def blank? = true

      def present? = false

      def configured? = false

      def enabled? = false

      def disabled? = true

      def to_s = ""

      def to_a = []

      def to_h = {}

      def method_missing(*)
        self
      end

      def respond_to_missing?(*)
        true
      end
    end

    NULL_VALUE = NullValue.new.freeze

    def initialize(values = {})
      @values = values.symbolize_keys.freeze
      freeze
    end

    def null?
      @values.empty?
    end

    def fetch(key, default = NULL_VALUE)
      @values.fetch(key.to_sym, default)
    end

    def [](key)
      fetch(key)
    end

    def method_missing(name, *, **)
      fetch(name)
    end

    def respond_to_missing?(*)
      true
    end

    def ==(other)
      other.is_a?(self.class) && @values == other.instance_variable_get(:@values)
    end

    alias eql? ==

    def hash
      [self.class, @values].hash
    end

    NULL = new.freeze
  end
end
