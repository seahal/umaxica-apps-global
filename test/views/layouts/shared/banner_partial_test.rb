# typed: false
# frozen_string_literal: true

require "test_helper"

class BannerPartialTest < ActionView::TestCase
  fixtures :user_banners, :client_banners, :users, :user_statuses, :clients, :client_statuses

  test "renders title and body when title is present" do
    render partial: "layouts/shared/banner", locals: { banner: user_banners(:current_user_banner) }

    assert_includes rendered, "User current banner"
    assert_includes rendered, "User current banner body"
  end

  test "renders body without title heading when title is blank" do
    render partial: "layouts/shared/banner", locals: { banner: client_banners(:untitled_client_banner) }

    assert_includes rendered, "VisitorAccount untitled banner body"
    assert_not_includes rendered, "<h2>"
  end
end
