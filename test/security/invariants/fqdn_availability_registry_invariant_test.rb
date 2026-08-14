# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # The FQDN availability switch is only fail-closed while its allowlist matches the hostnames the
    # router actually serves.
    #
    # Two directions of drift are both defects:
    #
    #   * A hostname added to `constraints(host:)` without a registry entry becomes reachable with no
    #     switch. The gate refuses it (see FqdnAvailabilityGateTest), so the surface is dead on
    #     arrival rather than unprotected -- but it is still broken.
    #   * A registry entry whose hostname no longer appears in any route is a switch an operator can
    #     pull with no effect, which is worse than no switch at all.
    class FqdnAvailabilityRegistryInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      ROUTE_PATHS = Rails.root.glob("config/routes/*.rb").freeze

      # Hostnames written as literals inside a `constraints(host: ...)` list.
      LITERAL_HOST_PATTERN = /"([a-z0-9][a-z0-9.-]*\.(?:localhost|app|com|org|net))"/

      test "every hostname literal used as a route constraint is registered" do
        unregistered = route_constraint_hostnames.reject { |host| FqdnAvailabilityRegistry.slot_for(host) }

        assert_empty unregistered,
                     "these hostnames route to a surface but have no availability switch: " \
                     "#{unregistered.sort.join(", ")}"
      end

      # Route files reference boot-config hosts by slot name rather than by literal, so the literal
      # scan above cannot see them. This covers the other half.
      #
      # The check is deliberately scoped to slots a route actually constrains on.
      # `ConfigValues::HostFamilyValues` also carries slots nothing serves -- `palm_corporate` and
      # `palm_staff` have configured hostnames but no `constraints(host:)` block, and the `acme_*`
      # family's values are the `base.*.localhost` development aliases already registered under the
      # `base_*` slots. Giving those a switch would give an operator a control with no effect.
      test "every boot-config host a route constrains on is registered" do
        unregistered =
          routed_host_slots.filter_map do |member|
            host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(member).host
            host if host.present? && FqdnAvailabilityRegistry.slot_for(host).nil?
          end

        assert_empty unregistered,
                     "these routed boot-config hosts have no availability switch: #{unregistered.sort.join(", ")}"
      end

      test "every registry slot resolves to at least one hostname" do
        empty = FqdnAvailabilityRegistry.slots.select { |slot| slot.hostnames.empty? }.map(&:name)

        assert_empty empty, "these slots have a switch but no hostname reaches them: #{empty.join(", ")}"
      end

      test "no hostname is claimed by two slots" do
        # `index` raises on a collision; calling it is the assertion.
        assert_nothing_raised { FqdnAvailabilityRegistry.index }
      end

      test "every slot has an availability-polarity feature flag" do
        FqdnAvailabilityRegistry::SLOT_NAMES.each do |slot|
          flag = FeatureFlags.fetch(FqdnAvailabilityRegistry.flag_name_for(slot))

          assert_equal :availability, flag.polarity,
                       "#{slot} must fail closed; a lost flag store cannot open a surface"
        end
      end

      private

      # Slot names appearing as `fetch(:hosts).<slot>.host` inside a route file.
      def routed_host_slots
        ROUTE_PATHS.flat_map { |path| File.read(path).scan(/fetch\(:hosts\)\.(\w+)\.host/) }
          .flatten.uniq.map(&:to_sym)
      end

      def route_constraint_hostnames
        ROUTE_PATHS.flat_map { |path| File.read(path).scan(LITERAL_HOST_PATTERN) }.flatten.uniq
      end
    end
  end
end
