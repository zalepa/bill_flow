require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "requires a client" do
    project = Project.new(name: "Test Project", hourly_rate: 50)
    assert_not project.valid?
    assert_includes project.errors[:client], "must exist"
  end

  test "requires a name" do
    project = projects(:web)
    assert project.valid?
    project.name = ""
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "hourly rate must be >= 0" do
    project = projects(:web)
    assert project.valid?
    project.hourly_rate = -10
    assert_not project.valid?
    assert_includes project.errors[:hourly_rate], "must be greater than or equal to 0"
  end

  test "status must be one of :active, :archived or :completed" do
    project = projects(:web)
    assert project.valid?

    project.active!
    assert project.active?

    project.archived!
    assert project.archived?

    project.completed!
    assert project.completed?


    assert_raises(ArgumentError) do
      project.status = :invalid_status
    end
  end
end
