module Crm
  class Task < ApplicationRecord
    self.table_name = 'crm_tasks'

    belongs_to :account
    belongs_to :contact
    belongs_to :assignee, class_name: 'User', foreign_key: 'assignee_id'
    belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
    belongs_to :completed_by, class_name: 'User', foreign_key: 'completed_by_id', optional: true

    enum priority: { low: 0, medium: 1, high: 2 }
    enum status: { pending: 0, completed: 1, overdue: 2 }

    validates :account_id, presence: true
    validates :contact_id, presence: true
    validates :assignee_id, presence: true
    validates :title, presence: true, length: { maximum: 255 }
    validates :due_date, presence: true
    validates :priority, presence: true
    validate :reminder_before_due_date

    scope :pending_and_overdue, -> { where(status: [:pending, :overdue]) }
    scope :due_before, ->(time) { where(status: :pending).where('due_date < ?', time) }
    scope :needs_reminder, -> { where(reminded: false, status: :pending).where('reminder_at <= ?', Time.current) }

    def complete!(completing_user)
      raise ActiveRecord::RecordInvalid, self if completed?

      transaction do
        update!(status: :completed, completed_at: Time.current, completed_by: completing_user)
        create_completion_activity!(completing_user)
      end
    end

    def reopen!
      raise ActiveRecord::RecordInvalid, self unless completed?

      update!(status: :pending, completed_at: nil, completed_by: nil)
    end

    private

    def reminder_before_due_date
      return if reminder_at.blank? || due_date.blank?

      errors.add(:reminder_at, 'must be before due_date') if reminder_at >= due_date
    end

    def create_completion_activity!(user)
      Crm::Activity.create!(
        account: account,
        contact: contact,
        user: user,
        activity_type: :task_completed,
        description: "Tarefa concluída: #{title}"
      )
    end
  end
end
