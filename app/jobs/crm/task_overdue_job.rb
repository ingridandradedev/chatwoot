# app/jobs/crm/task_overdue_job.rb
module Crm
  class TaskOverdueJob < ApplicationJob
    queue_as :scheduled_jobs

    def perform
      Crm::Task.due_before(Time.current).find_each do |task|
        task.update!(status: :overdue)
      rescue StandardError => e
        Rails.logger.error("CRM TaskOverdueJob failed for task##{task.id}: #{e.message}")
      end
    end
  end
end
