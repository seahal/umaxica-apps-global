# typed: false
# frozen_string_literal: true

require "test_helper"

# An avatar is bound to exactly one kind of subject, and the binding table is
# chosen from that kind. Binding through the wrong table would attach an avatar
# to a subject the surface never selected, so the mapping is closed and an
# unsupported kind is refused by name.
class AvatarBindingSubjectTypesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def creator_for(subject_type, subject)
    instance = AvatarProvisioning::Create.allocate
    instance.define_singleton_method(:subject_type) { subject_type }
    instance.define_singleton_method(:subject) { subject }
    instance
  end

  test "an unsupported subject kind is refused by name rather than bound anywhere" do
    error =
      assert_raises(ArgumentError) do
        creator_for("collective", Object.new).send(:create_binding!, Object.new)
      end

    assert_match(/unsupported subject_type/, error.message)
  end

  test "an unsupported account class is refused by name when binding a selector avatar" do
    error =
      assert_raises(ArgumentError) do
        BaseSelectorBootstrapAuthority.allocate.send(
          :bind_avatar_account!, avatar: Object.new, account: Object.new,
        )
      end

    assert_match(/unsupported account class/, error.message)
  end
end
