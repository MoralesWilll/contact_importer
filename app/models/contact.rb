class Contact < ApplicationRecord
  belongs_to :user
  belongs_to :contact_import
  scope :recent_first, -> { order(created_at: :desc) }

  # Validations
  validates :name, presence: true, format: { with: /\A[a-zA-Z\-\s]+\z/, message: "only allows letters and hyphens" }
  validates :date_of_birth, presence: true
  validates :phone, presence: true, format: { with: /\A\d{10,15}\z/, message: "must be a valid phone number" }
  validates :address, presence: true
  validates :email, presence: true, uniqueness: { scope: :user_id }, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Credit card validations
  validates :credit_card_number, presence: true # Should be encrypted!
  validates :card_network, presence: true
end
