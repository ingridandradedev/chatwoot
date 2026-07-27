# app/jobs/crm/task_reminder_job.rb
module Crm
  class TaskReminderJob < ApplicationJob
    queue_as :scheduled_jobs

    def perform
      Crm::Task.needs_reminder.find_each do |task|
        send_notification(task)
        task.update!(reminded: true)
      rescue StandardError => e
        Rails.logger.error("CRM TaskReminderJob failed for task##{task.id}: #{e.message}")
      end
    end

    private

    def send_notification(task)
      Notification.create!(
        account: task.account,
        user: task.assignee,
        notification_type: :crm_task_reminder,
        primary_actor: task,
        meta: {
          task_title: task.title,
          contact_name: task.contact.name,
          due_date: task.due_date.iso8601
        }
      )
    end
  end
end
