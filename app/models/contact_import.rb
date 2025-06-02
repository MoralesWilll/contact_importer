class ContactImport < ApplicationRecord
  belongs_to :user
  has_many :contacts, dependent: :destroy
  has_many :contact_import_errors, dependent: :destroy
  has_one_attached :csv_file

  validates :filename, presence: true
  validates :status, inclusion: { in: %w[on_hold processing failed finished] }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  def status_display
    case status
    when "on_hold" then "On Hold"
    when "processing" then "Processing"
    when "failed" then "Failed"
    when "finished" then "Finished"
    end
  end

  def success_rate
    return 0 if total_rows.zero?
    ((successful_imports.to_f / total_rows) * 100).round(1)
  end

  def mark_as_failed!(error_message)
    update!(status: "failed", completed_at: Time.current)
  end

  def start_processing!
    update!(status: "processing", started_at: Time.current)
  end
end
