# typed: false
# frozen_string_literal: true

require "test_helper"

# The OIDC callback concern is mixed into surfaces that each supply a different
# subset of seams. These are the answers it gives when a surface supplies none
# of them: a path target that cannot be resolved falls back to the site root, a
# session-limit rejection is still rendered, and the session management page
# resolves per surface rather than defaulting to one of them.
class OidcCallbackFallbacksTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(&definition)
    Class.new do
      include OidcCallback

      def render(*args, **kwargs)
        @rendered = [args, kwargs]
      end

      attr_reader :rendered

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "a path target that cannot be resolved falls back to the site root" do
    exploding =
      harness do
        def oidc_flow_value(_key) = raise(IOError, "flow store unavailable")
      end

    assert_equal "/", exploding.invoke(:session_limit_gate_pt)
  end

  test "a session-limit rejection is rendered even when the surface has no renderer of its own" do
    plain =
      harness do
        def oidc_flow_value(_key) = nil
      end

    plain.invoke(:render_oidc_session_limit_hard_reject, { message: "too many", http_status: :conflict })

    assert_equal [[], { plain: "too many", status: :conflict }], plain.rendered
  end

  test "a rejection with no message of its own falls back to the shared session-limit copy" do
    plain =
      harness do
        def oidc_flow_value(_key) = nil
      end

    plain.invoke(:render_oidc_session_limit_hard_reject, {})

    assert_equal [[], { plain: I18n.t("session_limit.login_limit_exceeded"), status: :forbidden }], plain.rendered
  end

  test "the session management page is resolved from whichever surface helper exists" do
    staff =
      harness do
        def sign_org_sign_in_session_path = "/org/in/session"
      end
    corporate =
      harness do
        def sign_com_sign_in_session_path = "/com/in/session"
      end
    bare = harness

    assert_equal "/org/in/session", staff.invoke(:oidc_session_management_path)
    assert_equal "/com/in/session", corporate.invoke(:oidc_session_management_path)
    assert_equal "/sign/in/session", bare.invoke(:oidc_session_management_path)
  end
end
