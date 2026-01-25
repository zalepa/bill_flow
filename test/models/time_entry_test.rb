require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  test "it must be associated with a project" do
    time_entry = time_entries(:thinking)
    time_entry.project = nil
    assert_not time_entry.valid?
  end

  test "it requires a description" do
    time_entry = time_entries(:thinking)
    assert time_entry.valid?
    time_entry.description = ""
    assert_not time_entry.valid?
  end

  test "it requires the end date to be after the start date" do
    time_entry = time_entries(:thinking)
    time_entry.ended_at = time_entry.started_at - 1.hour
    assert_not time_entry.valid?

    time_entry.ended_at = time_entry.started_at
    assert_not time_entry.valid?
  end

  test "#minutes returns how many minutes the time entry lasted" do
    time_entry = time_entries(:thinking)
    time_entry.ended_at = time_entry.started_at + 30.minutes
    assert_equal 30, time_entry.minutes
  end

  test "#hours returns how many hours the time entry lasted" do
    time_entry = time_entries(:thinking)
    time_entry.ended_at = time_entry.started_at + 90.minutes
    assert_equal 1.5, time_entry.hours
  end
end
