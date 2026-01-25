require "test_helper"

class ClientTest < ActiveSupport::TestCase
  # Uniqueness
  test "email must be unique" do
    bad_client = clients(:acme).dup
    assert bad_client.invalid?
    assert_includes bad_client.errors[:email], "has already been taken"
  end

  # Blankness
  test "name, email, and company must be present" do
    client = Client.new
    assert client.invalid?
    [ :name, :email, :company ].each do |attr|
      assert_includes client.errors[attr], "can't be blank"
    end
  end

  test "email must have valid format" do
    invalid_emails = [ "plainaddress", "@missingusername.com", "username@.com", "username@com", "username@domain..com" ]
    invalid_emails.each do |email|
      client = Client.new(name: "Test Client", company: "Test Company", email: email)
      assert client.invalid?, "#{email.inspect} should be invalid"
      assert_includes client.errors[:email], "is invalid"
    end

    valid_emails = [ "test@example.com", "user.name@domain.co.uk", "user+tag@example.org" ]
    valid_emails.each do |email|
      client = Client.new(name: "Test Client", company: "Test Company", email: email)
      assert client.valid?, "#{email.inspect} should be valid"
    end
  end
end
