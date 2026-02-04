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

  test "can have zero or more time entries" do
    project = projects(:web)
    assert_kind_of ActiveRecord::Associations::CollectionProxy, project.time_entries

    project.time_entries = []
    assert project.valid?

    project.time_entries.create(description: "Hello", started_at: Time.current, ended_at: Time.current + 1.hour, billable: true)
    assert_equal 1, project.time_entries.count
  end

  test "destroying project destroys associated time entries" do
    project = projects(:web)

    project.time_entries.destroy_all

    project.time_entries.create!(
      description: "Work",
      started_at: Time.current,
      ended_at: Time.current + 1.hour,
      billable: true
    )

    assert_difference "TimeEntry.count", -1 do
      project.destroy
    end
  end

  test "active scope only returns active projects" do
    project = projects(:web)
    project.active! # ensure the project is active

    active_projects = Project.active
    assert_equal 1, active_projects.count

    project.archived!
    active_projects = Project.active
    assert_equal 0, active_projects.count
  end
end
