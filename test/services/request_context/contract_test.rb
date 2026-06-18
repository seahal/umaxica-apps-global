# typed: false
# frozen_string_literal: true

require "test_helper"

module RequestContext
  class ContractTest < ActiveSupport::TestCase
    test "public key families partition the public key set" do
      assert_equal %i(ri), RequestContextContract.required_keys
      assert_equal %i(pt nt), RequestContextContract.redirect_target_keys
      assert_equal %i(lx ct tz cu df tf mo dn ps), RequestContextContract.optional_overlay_keys

      union = RequestContextContract.required_keys +
        RequestContextContract.redirect_target_keys +
        RequestContextContract.optional_overlay_keys

      assert_equal union.sort, RequestContextContract.public_keys.sort
      assert_equal union.uniq.size, RequestContextContract.public_keys.size
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
      }

      assert_equal expected, RequestContextContract.internal_names
      assert_equal :language, RequestContextContract.internal_name(:lx)
      assert_equal :region, RequestContextContract.internal_name("ri")
    end

    test "family classifies each public key" do
      assert_equal :required, RequestContextContract.family(:ri)
      assert_equal :path_target, RequestContextContract.family(:pt)
      assert_equal :navigation_target, RequestContextContract.family(:nt)
      assert_equal :optional_overlay, RequestContextContract.family(:lx)
      assert_equal :optional_overlay, RequestContextContract.family(:ps)
    end

    test "redirect_target_key? recognizes only pt and nt" do
      assert RequestContextContract.redirect_target_key?(:pt)
      assert RequestContextContract.redirect_target_key?("nt")
      assert_not RequestContextContract.redirect_target_key?(:xt)
      assert_not RequestContextContract.redirect_target_key?(:rt)
      assert_not RequestContextContract.redirect_target_key?(:ri)
      assert_not RequestContextContract.redirect_target_key?(:lx)
    end

    test "normalize lowercases overlay values but preserves target casing" do
      assert_equal "en", RequestContextContract.normalize(:lx, "EN")
      assert_equal "dark", RequestContextContract.normalize(:ct, "Dark")
      assert_equal "asia/tokyo", RequestContextContract.normalize(:tz, "Asia/Tokyo")
      assert_equal "12", RequestContextContract.normalize(:tf, "hour_12")
      assert_equal "24", RequestContextContract.normalize(:tf, "24")
      assert_equal "rd", RequestContextContract.normalize(:mo, "reduced")
      assert_equal "st", RequestContextContract.normalize(:mo, "st")
      assert_equal "cp", RequestContextContract.normalize(:dn, "compact")
      assert_equal "st", RequestContextContract.normalize(:dn, "standard")
      assert_equal "Opaque.Token-Value_123", RequestContextContract.normalize(:pt, "Opaque.Token-Value_123")
      assert_equal "Dashboard", RequestContextContract.normalize(:nt, "Dashboard")
    end

    test "internal_name raises on unknown key" do
      assert_raises(KeyError) { RequestContextContract.internal_name(:unknown) }
    end
  end
end
