# typed: false
# frozen_string_literal: true

module Acme
  class OrganizationQuotaPolicy
    def initialize(surface:, principal:, scope: nil, limit: QuotaLimits::ORGANIZATION_LIMIT)
      @surface = surface.to_sym
      @principal = principal
      @scope = scope
      @limit = limit
    end

    def allowed?
      current_count < limit
    end

    def exceeded?
      !allowed?
    end

    def limit
      @limit
    end

    def current_count
      scope_relation.count
    end

    def remaining
      [limit - current_count, 0].max
    end

    private

    attr_reader :surface, :principal, :scope

    def scope_relation
      scope || organization_class.all
    end

    def organization_class
      case surface
      when :app then Enterprise
      when :org then Bureau
      when :com then Company
      else
        raise ArgumentError, "unsupported surface: #{surface.inspect}"
      end
    end
  end
end
