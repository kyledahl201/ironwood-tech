require "test_helper"

class AccountTest < ActionDispatch::IntegrationTest
  def change(fields)
    patch portal_account_path, params: { user: fields }
  end

  test "the account page needs a sign-in and is linked from the menu" do
    get portal_account_path
    assert_redirected_to new_session_path
    sign_in_as users(:one)
    get portal_account_path
    assert_response :success
    assert_select "h1", text: "Your account"
    assert_select "a[href=?]", portal_account_path, text: "Account"
    assert_select "input[name='user[email_address]'][value='one@example.com']"
    assert_select "input[type=password][value]", count: 0
  end

  test "a student changes their name and email with their current password, and signs in with the new email" do
    sign_in_as users(:one)
    change name: "Sam Newname", email_address: " Sam.New@Example.com ", password: "", password_confirmation: "", current_password: "password"
    assert_redirected_to portal_account_path
    user = users(:one).reload
    assert_equal "Sam Newname", user.name
    assert_equal "sam.new@example.com", user.email_address
    assert user.authenticate("password"), "an empty new password keeps the old one"
    assert_equal "Saved.", flash[:notice]
    sign_out
    post session_path, params: { email_address: "sam.new@example.com", password: "password" }
    assert_redirected_to portal_url
  end

  test "nothing changes without the right current password" do
    sign_in_as users(:one)
    [ "", "wrong-password" ].each do |guess|
      change name: "Mallory", email_address: "mallory@example.com", password: "a-brand-new-password", password_confirmation: "a-brand-new-password", current_password: guess
      assert_response :unprocessable_entity
      assert_select ".errors", text: /current password isn't right, so nothing was changed/
      # What was typed is kept in the form, but the page header still shows the saved account.
      assert_select "input[name='user[name]'][value='Mallory']"
      assert_select "input[type=password][value]", count: 0
    end
    user = users(:one).reload
    assert_equal "Sam Student", user.name
    assert_equal "one@example.com", user.email_address
    assert user.authenticate("password")
  end

  test "a new password must be long enough and typed the same twice" do
    sign_in_as users(:one)
    change name: "Sam Student", email_address: "one@example.com", password: "short", password_confirmation: "short", current_password: "password"
    assert_response :unprocessable_entity
    assert_select ".errors", text: /too short/
    change name: "Sam Student", email_address: "one@example.com", password: "a-brand-new-password", password_confirmation: "a-different-password", current_password: "password"
    assert_response :unprocessable_entity
    assert_select ".errors", text: /doesn't match/
    assert users(:one).reload.authenticate("password")
  end

  test "a new password signs out other devices and keeps this one" do
    other = users(:one).sessions.create!
    sign_in_as users(:one)
    here = Current.session
    change name: "Sam Student", email_address: "one@example.com", password: "a-brand-new-password", password_confirmation: "a-brand-new-password", current_password: "password"
    assert_redirected_to portal_account_path
    assert_match "other devices have been signed out", flash[:notice]
    assert_not Session.exists?(other.id)
    assert Session.exists?(here.id)
    assert users(:one).reload.authenticate("a-brand-new-password")
    get portal_account_path
    assert_response :success
  end

  test "an email someone else uses is refused, and a role can't be set from this page" do
    sign_in_as users(:one)
    change name: "Sam Student", email_address: "two@example.com", current_password: "password"
    assert_response :unprocessable_entity
    assert_select ".errors", text: /already been taken/
    change name: "Sam Student", email_address: "one@example.com", role: "admin", current_password: "password"
    assert_not users(:one).reload.admin?
  end

  test "the owner changes their own login, and a restart doesn't bring the placeholder owner back" do
    sign_in_as users(:owner)
    get portal_account_path
    assert_select ".eyebrow", text: "Owner account"
    change name: "Owner Person", email_address: "me@example.com", password: "my-own-long-password", password_confirmation: "my-own-long-password", current_password: "password"
    assert_redirected_to portal_account_path
    assert users(:owner).reload.admin?
    assert_no_difference -> { User.count } do
      Rails.application.load_seed
    end
    assert_not User.exists?(email_address: "owner@example.com")
  end
end
