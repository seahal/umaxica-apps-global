# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthTest < ActiveSupport::TestCase
  FakeCheck =
    Struct.new(:result) do
      def call = result
    end

  test "result serializes public fields without internal topology" do
    result = Health::Check::Result.new(kind: :database, status: :unready, message: "Dependency unavailable")

    assert_equal({ kind: "database", status: "unready" }, result.as_public_json)
  end

  test "result rejects unknown statuses" do
    assert_raises(ArgumentError) do
      Health::Check::Result.new(kind: :database, status: :broken)
    end
  end

  test "report aggregates ok checks" do
    profile = fake_profile(checks: [])
    checks = [Health::Check::Result.new(kind: :database, status: :ok)]

    report = Health::Report.aggregate(profile: profile, probe: :ready, checks: checks)

    assert_equal :ok, report.status
    assert_equal "ready", report.as_public_json[:probe]
  end

  test "status policy maps acceptable degraded by profile" do
    degraded = Health::Check::Result.new(kind: :database, status: :degraded_acceptable)
    strict_policy = Health::StatusPolicy.new
    accepting_policy = Health::StatusPolicy.new(acceptable_degraded_kinds: [:database])

    assert_equal :unready, strict_policy.status_for([degraded])
    assert_equal :degraded_acceptable, accepting_policy.status_for([degraded])
  end

  test "http status mapping is centralized" do
    assert_equal 200, Health::StatusPolicy.http_status(:ok, probe: :ready)
    assert_equal 200, Health::StatusPolicy.http_status(:degraded_acceptable, probe: :ready)
    assert_equal 503, Health::StatusPolicy.http_status(:unready, probe: :ready)
    assert_equal 503, Health::StatusPolicy.http_status(:starting, probe: :ready)
    assert_equal 200, Health::StatusPolicy.http_status(:starting, probe: :live)
  end

  test "profile dependency allowlists are explicit" do
    assert_equal [AppRpRecord, AppSettingRecord, AppSignalRecord, AvatarRecord, OccurrenceRecord],
                 Health::Profiles::App.record_classes
    assert_equal [OrgRpRecord, OrgSettingRecord, OrgSignalRecord], Health::Profiles::Org.record_classes
    assert_equal [AppPrincipalRecord, AppTicketRecord, AppSettingRecord], Health::Profiles::SignApp.record_classes
  end

  test "readiness checks only the current profile dependencies" do
    called = []
    profile = fake_profile(
      checks: [
        FakeCheck.new(Health::Check::Result.new(kind: :database, status: :ok)),
        FakeCheck.new(Health::Check::Result.new(kind: :database, status: :ok)),
      ],
    )
    profile.readiness_checks.each_with_index do |check, index|
      check.define_singleton_method(:call) do
        called << index
        result
      end
    end

    report = Health::Readiness.new(profile: profile, cache: ActiveSupport::Cache::MemoryStore.new).call

    assert_equal :ok, report.status
    assert_equal [0, 1], called
  end

  test "readiness cache key isolates profile probe and revision" do
    cache = ActiveSupport::Cache::MemoryStore.new
    first_profile = fake_profile(
      cache_key: "first",
      checks: [FakeCheck.new(Health::Check::Result.new(kind: :database, status: :ok))],
    )
    second_profile = fake_profile(
      cache_key: "second",
      checks: [FakeCheck.new(Health::Check::Result.new(kind: :database, status: :unready))],
    )

    assert_equal :ok, Health::Readiness.new(profile: first_profile, cache: cache).call.status
    assert_equal :unready, Health::Readiness.new(profile: second_profile, cache: cache).call.status
  end

  test "readiness cache reuses result within ttl and expires transitions" do
    cache = ActiveSupport::Cache::MemoryStore.new
    result = Health::Check::Result.new(kind: :database, status: :ok)
    calls = 0
    check = Object.new
    check.define_singleton_method(:call) do
      calls += 1
      result
    end
    profile = fake_profile(checks: [check])

    assert_equal :ok, Health::Readiness.new(profile: profile, cache: cache).call.status
    result = Health::Check::Result.new(kind: :database, status: :unready)

    assert_equal :ok, Health::Readiness.new(profile: profile, cache: cache).call.status
    assert_equal 1, calls

    travel Health::Readiness::CACHE_TTL + 1.second

    assert_equal :unready, Health::Readiness.new(profile: profile, cache: cache).call.status
    assert_equal 2, calls
  end

  test "readiness timeout returns unready report" do
    check = Object.new
    check.define_singleton_method(:call) { raise Health::DeadlineExceeded }
    profile = fake_profile(checks: [check])

    report = Health::Readiness.new(profile: profile, cache: ActiveSupport::Cache::MemoryStore.new).call

    assert_equal :unready, report.status
  end

  test "startup uses only boot check" do
    report = Health::Startup.call(
      profile: fake_profile(
        checks: [FakeCheck.new(Health::Check::Result.new(kind: :database, status: :unready))],
      ),
    )

    assert_equal [:boot], report.checks.map(&:kind)
  end

  private

  def fake_profile(cache_key: "fake", checks:)
    Struct.new(:cache_key, :surface_label, :status_policy, :readiness_checks).new(
      cache_key,
      "fake",
      Health::StatusPolicy.new,
      checks,
    )
  end
end
