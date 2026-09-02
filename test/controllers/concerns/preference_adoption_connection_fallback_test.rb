# typed: false
# frozen_string_literal: true

require "test_helper"

# Every preference write in this concern is wrapped so that it runs on the
# writing connection of whichever database the record belongs to. Records whose
# class carries no abstract connection ancestor have no such connection to
# switch to, and the write has to happen anyway rather than be skipped -- the
# fallback that decides this is what these tests pin, together with the
# consent-recency rule that chooses which side wins.
class PreferenceAdoptionConnectionFallbackTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # A preference-shaped record with no ActiveRecord ancestry at all, so
  # `preference_connection_class` finds nothing to switch to.
  class PlainConsentRecord
    attr_reader :updates, :consented_at

    def initialize(consented_at: nil)
      @consented_at = consented_at
      @updates = []
    end

    def consented = true

    def functional = true

    def performant = false

    def targetable = false

    def update!(attributes)
      @updates << attributes
    end
  end

  class PlainCookie
    attr_reader :updates, :consented_at

    def initialize(consented_at: nil)
      @consented_at = consented_at
      @updates = []
    end

    def consented = true

    def functional = false

    def performant = true

    def targetable = false

    def update!(attributes)
      @updates << attributes
    end
  end

  # No `consented` reader, so the concern reaches for the `<class>_cookie`
  # association instead. Named to make `class.name.underscore` predictable.
  class PlainCookieOwner
    attr_reader :cookie, :created

    def initialize(cookie: nil)
      @cookie = cookie
      @created = false
    end

    def self.name = "PlainCookieOwner"

    def plain_cookie_owner_cookie = @cookie

    def create_plain_cookie_owner_cookie!
      @created = true
      @cookie = PlainCookie.new
    end
  end

  class Harness
    include PreferenceAdoption

    attr_accessor :preferences

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a consent snapshot is written directly when the target has no connection class to switch to" do
    target = PlainConsentRecord.new

    @harness.invoke(:apply_consent_snapshot!, target, { consented: true, functional: false })

    assert_equal [{ consented: true, functional: false }], target.updates
  end

  test "a target that keeps consent on a cookie association is written through that association" do
    cookie = PlainCookie.new
    owner = PlainCookieOwner.new(cookie: cookie)

    @harness.invoke(:apply_consent_snapshot!, owner, { consented: true })

    assert_equal [{ consented: true }], cookie.updates
  end

  test "a target with no cookie row yet has one created before the snapshot is written" do
    owner = PlainCookieOwner.new

    @harness.invoke(:apply_consent_snapshot!, owner, { consented: true })

    assert owner.created
    assert_equal [{ consented: true }], owner.cookie.updates
  end

  test "the more recently recorded consent wins and is copied onto the other side" do
    browser = PlainConsentRecord.new(consented_at: Time.current)
    principal = PlainConsentRecord.new(consented_at: 1.day.ago)
    @harness.preferences = browser

    @harness.invoke(:reconcile_cookie_consent!, principal)

    assert_equal 1, principal.updates.size
    assert_empty browser.updates
  end

  test "the principal side wins when only it has recorded consent" do
    browser = PlainConsentRecord.new
    principal = PlainConsentRecord.new(consented_at: 1.day.ago)
    @harness.preferences = browser

    @harness.invoke(:reconcile_cookie_consent!, principal)

    assert_equal 1, browser.updates.size
    assert_empty principal.updates
  end

  test "copying consent between two column-backed records writes straight to the target" do
    source = PlainConsentRecord.new(consented_at: Time.current)
    target = PlainConsentRecord.new

    @harness.invoke(:copy_cookie_consent!, source, target, nil, nil)

    assert_equal [{ consented: true, functional: true, performant: false, targetable: false }], target.updates
  end

  test "copying consent from a cookie-backed source onto a cookie-backed target writes to the target cookie" do
    source = PlainCookieOwner.new(cookie: PlainCookie.new)
    target_cookie = PlainCookie.new
    target = PlainCookieOwner.new(cookie: target_cookie)

    @harness.invoke(:copy_cookie_consent!, source, target, nil, nil)

    assert_equal [{ consented: true, functional: false, performant: true, targetable: false }], target_cookie.updates
  end

  test "copying consent stops when a cookie-backed source has no cookie row" do
    source = PlainCookieOwner.new
    target = PlainConsentRecord.new

    assert_nil @harness.invoke(:copy_cookie_consent!, source, target, nil, nil)
    assert_empty target.updates
  end
end
