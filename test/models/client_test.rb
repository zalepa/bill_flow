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

  test "has a collection of projects" do
    client = clients(:acme)
    assert_respond_to client, :projects
  end

  test "a client can have zero projects" do
    client = clients(:acme)
    client.projects.destroy_all
    assert_equal 0, client.projects.count
  end

  test "a client can have one or more projects" do
    client = clients(:acme)
    client.projects.destroy_all

    client.projects.create(name: "Project 1")
    assert_equal 1, client.projects.count

    client.projects.create(name: "Project 2")
    assert_equal 2, client.projects.count
  end

  test "destroying client destroys associated projects and time entries" do
    client = clients(:acme)

    client.projects.destroy_all

    project = client.projects.create(name: "Project 1")

    project.time_entries.create!(
      description: "Work",
      started_at: Time.current,
      ended_at: Time.current + 1.hour,
      billable: true
    )

    assert_difference [ "TimeEntry.count", "Project.count" ], -1 do
      client.destroy
    end
  end
end
