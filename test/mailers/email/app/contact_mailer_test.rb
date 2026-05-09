# typed: false
# frozen_string_literal: true

require "test_helper"

class Email::App::ContactMailerTest < ActionMailer::TestCase
  test "create" do
    mail = Email::App::ContactMailer.create

    assert_equal "Create", mail.subject
    # assert_equal [ "to@example.org" ], mail.to
    assert_equal ["from@umaxica.app"], mail.from
    assert_match "pass", mail.body.encoded
  end

  test "create with email_address parameter" do
    mail = Email::App::ContactMailer.with(email_address: "test@example.com", pass_code: "123456").create

    assert_equal "Create", mail.subject
    assert_equal ["test@example.com"], mail.to
    assert_equal ["from@umaxica.app"], mail.from
  end

  test "create with pass_code parameter" do
    mail = Email::App::ContactMailer.with(email_address: "user@example.com", pass_code: "654321").create

    assert_match "654321", mail.body.encoded
  end

  test "should set pass_code instance variable" do
    mail = Email::App::ContactMailer.with(email_address: "user@example.com", pass_code: "111111").create

    assert_match "111111", mail.body.encoded
  end
end
