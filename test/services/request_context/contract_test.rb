# typed: false
# frozen_string_literal: true

require "test_helper"

module RequestContext
  class ContractTest < ActiveSupport::TestCase
    test "public key families partition the public key set" do
      assert_equal %i(ri), Contract.required_keys
      assert_equal %i(rt), Contract.return_target_keys
      assert_equal %i(lx ct tz cu df tf mo dn pp), Contract.optional_overlay_keys

      union = Contract.required_keys + Contract.return_target_keys + Contract.optional_overlay_keys

      assert_equal union.sort, Contract.public_keys.sort
      assert_equal union.uniq.size, Contract.public_keys.size
    end

    test "internal names cover the canonical mapping" do
      expected = {
        ri: :region,
        rt: :return_target,
        lx: :language,
        ct: :theme,
        tz: :timezone,
        cu: :currency,
        df: :date_format,
        tf: :time_format,
        mo: :motion,
        dn: :density,
        pp: :items_per_page,
      }

      assert_equal expected, Contract.internal_names
      assert_equal :language, Contract.internal_name(:lx)
      assert_equal :region, Contract.internal_name("ri")
    end

    test "family classifies each public key" do
      assert_equal :required, Contract.family(:ri)
      assert_equal :return_target, Contract.family(:rt)
      assert_equal :optional_overlay, Contract.family(:lx)
      assert_equal :optional_overlay, Contract.family(:pp)
    end

    test "return_target_key? recognizes only :rt" do
      assert Contract.return_target_key?(:rt)
      assert Contract.return_target_key?("rt")
      assert_not Contract.return_target_key?(:ri)
      assert_not Contract.return_target_key?(:lx)
    end

    test "normalize lowercases overlay values but preserves rt and tz casing" do
      assert_equal "en", Contract.normalize(:lx, "EN")
      assert_equal "dark", Contract.normalize(:ct, "Dark")
      assert_equal "Asia/Tokyo", Contract.normalize(:tz, "Asia/Tokyo")
      assert_equal "Opaque.Token-Value_123", Contract.normalize(:rt, "Opaque.Token-Value_123")
    end

    test "internal_name raises on unknown key" do
      assert_raises(KeyError) { Contract.internal_name(:unknown) }
    end
  end
end
