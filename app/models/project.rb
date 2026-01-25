class Project < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }

  enum :status, [ :active, :archived, :completed ]

  has_many :time_entries, dependent: :destroy
end
