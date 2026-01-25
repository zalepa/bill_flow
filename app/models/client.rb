class Client < ApplicationRecord
  validates :name, :email, :company, presence: true
  validates :email, uniqueness: true, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i }
  normalizes :email, with: ->(email) { email.strip.downcase }
end
