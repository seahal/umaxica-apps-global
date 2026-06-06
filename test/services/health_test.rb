# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthTest < ActiveSupport::TestCase
  FakeCheck =
    Struct.new(:result) do
      def call = result
    end

  test "result serializes public fields without internal topology" do
    result = HealthCheckResult.new(kind: :database, status: :unready, message: "Dependency unavailable")

    assert_equal({ kind: "database", status: "unready" }, result.as_public_json)
  end

  test "result rejects unknown statuses" do
    assert_raises(ArgumentError) do
      HealthCheckResult.new(kind: :database, status: :broken)
    end
  end

  test "report aggregates ok checks" do
    profile = fake_profile(checks: [])
    checks = [HealthCheckResult.new(kind: :database, status: :ok)]

    report = HealthReport.aggregate(profile: profile, probe: :ready, checks: checks)

    assert_equal :ok, report.status
    assert_equal "ready", report.as_public_json[:probe]
  end

  test "status policy maps acceptable degraded by profile" do
    degraded = HealthCheckResult.new(kind: :database, status: :degraded_acceptable)
    strict_policy = HealthStatusPolicy.new
    accepting_policy = HealthStatusPolicy.new(acceptable_degraded_kinds: [:database])

    assert_equal :unready, strict_policy.status_for([degraded])
    assert_equal :degraded_acceptable, accepting_policy.status_for([degraded])
  end

  test "http status mapping is centralized" do
    assert_equal 200, HealthStatusPolicy.http_status(:ok, probe: :ready)
    assert_equal 200, HealthStatusPolicy.http_status(:degraded_acceptable, probe: :ready)
    assert_equal 503, HealthStatusPolicy.http_status(:unready, probe: :ready)
    assert_equal 503, HealthStatusPolicy.http_status(:starting, probe: :ready)
    assert_equal 200, HealthStatusPolicy.http_status(:starting, probe: :live)
  end

  test "profile dependency allowlists are explicit" do
    assert_equal [AppRpRecord, AppSettingRecord, AppSignalRecord, AvatarRecord, OccurrenceRecord],
                 HealthProfilesApp.record_classes
    assert_equal [OrgRpRecord, OrgSettingRecord, OrgSignalRecord], HealthProfilesOrg.record_classes
    assert_equal [AppPrincipalRecord, AppTicketRecord, AppSettingRecord], HealthProfilesSignApp.record_classes
  end

  test "readiness checks only the current profile dependencies" do
    called = []
    profile = fake_profile(
      checks: [
        FakeCheck.new(HealthCheckResult.new(kind: :database, status: :ok)),
        FakeCheck.new(HealthCheckResult.new(kind: :database, status: :ok)),
      ],
    )
    profile.readiness_checks.each_with_index do |check, index|
      check.define_singleton_method(:call) do
        called << index
        result
      end
    end

    report = HealthReadiness.new(profile: profile, cache: ActiveSupport::Cache::MemoryStore.new).call

    assert_equal :ok, report.status
    assert_equal [0, 1], called
  end

  test "readiness cache key isolates profile probe and revision" do
    cache = ActiveSupport::Cache::MemoryStore.new
    first_profile = fake_profile(
      cache_key: "first",
      checks: [FakeCheck.new(HealthCheckResult.new(kind: :database, status: :ok))],
    )
    second_profile = fake_profile(
      cache_key: "second",
      checks: [FakeCheck.new(HealthCheckResult.new(kind: :database, status: :unready))],
    )

    assert_equal :ok, HealthReadiness.new(profile: first_profile, cache: cache).call.status
    assert_equal :unready, HealthReadiness.new(profile: second_profile, cache: cache).call.status
  end

  test "readiness cache reuses result within ttl and expires transitions" do
    cache = ActiveSupport::Cache::MemoryStore.new
    result = HealthCheckResult.new(kind: :database, status: :ok)
    calls = 0
    check = Object.new
    check.define_singleton_method(:call) do
      calls += 1
      result
    end
    profile = fake_profile(checks: [check])

    assert_equal :ok, HealthReadiness.new(profile: profile, cache: cache).call.status
    result = HealthCheckResult.new(kind: :database, status: :unready)

    assert_equal :ok, HealthReadiness.new(profile: profile, cache: cache).call.status
    assert_equal 1, calls

    travel HealthReadiness::CACHE_TTL + 1.second

    assert_equal :unready, HealthReadiness.new(profile: profile, cache: cache).call.status
    assert_equal 2, calls
  end

  test "readiness timeout returns unready report" do
    check = Object.new
    check.define_singleton_method(:call) { raise Health::DeadlineExceeded }
    profile = fake_profile(checks: [check])

    report = HealthReadiness.new(profile: profile, cache: ActiveSupport::Cache::MemoryStore.new).call

    assert_equal :unready, report.status
  end

  test "startup uses only boot check" do
    report = HealthStartup.call(
      profile: fake_profile(
        checks: [FakeCheck.new(HealthCheckResult.new(kind: :database, status: :unready))],
      ),
    )

    assert_equal [:boot], report.checks.map(&:kind)
  end

  private

  def fake_profile(cache_key: "fake", checks:)
    Struct.new(:cache_key, :surface_label, :status_policy, :readiness_checks).new(
      cache_key,
      "fake",
      HealthStatusPolicy.new,
      checks,
    )
  end
end
