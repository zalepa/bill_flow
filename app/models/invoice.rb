class Invoice < ApplicationRecord
  belongs_to :client
  has_many :line_items, dependent: :destroy

  enum :status, [ :draft, :sent, :paid, :overdue ]
  validates :number, presence: true, uniqueness: { scope: :client_id }
  validate :due_date_after_issued_date
  validates :issued_on, presence: true, unless: :draft?
  validates :due_on, presence: true, unless: :draft?

  scope :overdue, -> { where("due_on < ? AND status != ?", Date.today, statuses[:paid]) }

  def total
    line_items.sum(&:total)
  end

  def generate_number
    last_invoice = client.invoices.order(number: :desc).first
    self.number = last_invoice ? last_invoice.number + 1 : 1001
    # check if number is unique for the client
    while client.invoices.exists?(number: number)
      self.number += 1
    end
  end

  private

  def due_date_after_issued_date
    return if due_on.blank? || issued_on.blank?
    if due_on <= issued_on
      errors.add(:due_on, "must be after issued on date")
    end
  end
end
