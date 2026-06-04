# typed: false
# frozen_string_literal: true

require "test_helper"

module RequestContext
  class ContractTest < ActiveSupport::TestCase
    test "public key families partition the public key set" do
      assert_equal %i(ri), Contract.required_keys
      assert_equal %i(pt nt), Contract.redirect_target_keys
      assert_equal %i(lx ct tz cu df tf mo dn ps r18s), Contract.optional_overlay_keys

      union = Contract.required_keys + Contract.redirect_target_keys + Contract.optional_overlay_keys

      assert_equal union.sort, Contract.public_keys.sort
      assert_equal union.uniq.size, Contract.public_keys.size
    end

    test "internal names cover the canonical mapping" do
      expected = {
        ri: :region,
        pt: :path_target,
        nt: :navigation_target,
        lx: :language,
        ct: :theme,
        tz: :timezone,
        cu: :currency,
        df: :date_format,
        tf: :time_format,
        mo: :motion,
        dn: :density,
        ps: :page_size,
        r18s: :adult_content_gate,
      }

      assert_equal expected, Contract.internal_names
      assert_equal :language, Contract.internal_name(:lx)
      assert_equal :region, Contract.internal_name("ri")
    end

    test "family classifies each public key" do
      assert_equal :required, Contract.family(:ri)
      assert_equal :path_target, Contract.family(:pt)
      assert_equal :navigation_target, Contract.family(:nt)
      assert_equal :optional_overlay, Contract.family(:lx)
      assert_equal :optional_overlay, Contract.family(:ps)
      assert_equal :optional_overlay, Contract.family(:r18s)
    end

    test "redirect_target_key? recognizes only pt and nt" do
      assert Contract.redirect_target_key?(:pt)
      assert Contract.redirect_target_key?("nt")
      assert_not Contract.redirect_target_key?(:xt)
      assert_not Contract.redirect_target_key?(:rt)
      assert_not Contract.redirect_target_key?(:ri)
      assert_not Contract.redirect_target_key?(:lx)
    end

    test "normalize lowercases overlay values but preserves target casing" do
      assert_equal "en", Contract.normalize(:lx, "EN")
      assert_equal "dark", Contract.normalize(:ct, "Dark")
      assert_equal "asia/tokyo", Contract.normalize(:tz, "Asia/Tokyo")
      assert_equal "12", Contract.normalize(:tf, "hour_12")
      assert_equal "24", Contract.normalize(:tf, "24")
      assert_equal "rd", Contract.normalize(:mo, "reduced")
      assert_equal "st", Contract.normalize(:mo, "st")
      assert_equal "cp", Contract.normalize(:dn, "compact")
      assert_equal "st", Contract.normalize(:dn, "standard")
      assert_equal "Opaque.Token-Value_123", Contract.normalize(:pt, "Opaque.Token-Value_123")
      assert_equal "Dashboard", Contract.normalize(:nt, "Dashboard")
    end

    test "internal_name raises on unknown key" do
      assert_raises(KeyError) { Contract.internal_name(:unknown) }
    end
  end
end
