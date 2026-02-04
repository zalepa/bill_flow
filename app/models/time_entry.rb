class TimeEntry < ApplicationRecord
  belongs_to :project
  validates :description, presence: true
  validate :ended_at_after_started_at

  scope :billable, -> { where(billable: true) }

  def minutes
    return 0 if ended_at.blank? || started_at.blank?

    ((ended_at - started_at) / 60).to_i
  end

  def hours
    return 0.0 if ended_at.blank? || started_at.blank?

    ((ended_at - started_at) / 3600).to_f
  end

  private

  def ended_at_after_started_at
    return if ended_at.blank? || started_at.blank?

    if ended_at <= started_at
      errors.add(:ended_at, "must be after the start time")
    end
  end

  alias :duration :minutes
end
