require 'rails_helper'

RSpec.describe Crm::TaskReminderJob do
  subject(:job) { described_class.new }

  let(:account) { create(:account) }

  it 'enqueues the job on scheduled_jobs queue' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  describe '#perform' do
    context 'when there are tasks needing reminder' do
      let!(:task) do
        create(:crm_task, account: account, status: :pending,
                          reminded: false, reminder_at: 10.minutes.ago,
                          due_date: 1.day.from_now)
      end

      it 'creates a Notification for the task assignee' do
        expect { job.perform }.to change(Notification, :count).by(1)

        notification = Notification.last
        expect(notification.account).to eq(task.account)
        expect(notification.user).to eq(task.assignee)
        expect(notification.notification_type).to eq('crm_task_reminder')
        expect(notification.primary_actor).to eq(task)
      end

      it 'sets reminded to true' do
        job.perform

        expect(task.reload.reminded).to be(true)
      end
    end

    context 'when a task has already been reminded' do
      let!(:reminded_task) do
        create(:crm_task, account: account, status: :pending,
                          reminded: true, reminder_at: 10.minutes.ago,
                          due_date: 1.day.from_now)
      end

      it 'does not process the task' do
        expect { job.perform }.not_to change(Notification, :count)
      end
    end

    context 'when a task is completed' do
      let!(:completed_task) do
        create(:crm_task, :completed, account: account,
                          reminded: false, reminder_at: 10.minutes.ago,
                          due_date: 1.day.from_now)
      end

      it 'does not process the task' do
        expect { job.perform }.not_to change(Notification, :count)
      end
    end

    context 'when reminder_at is in the future' do
      let!(:future_reminder_task) do
        create(:crm_task, account: account, status: :pending,
                          reminded: false, reminder_at: 1.hour.from_now,
                          due_date: 1.day.from_now)
      end

      it 'does not process the task' do
        expect { job.perform }.not_to change(Notification, :count)
      end
    end

    context 'when an individual task errors during processing' do
      let!(:valid_task) do
        create(:crm_task, account: account, status: :pending,
                          reminded: false, reminder_at: 10.minutes.ago,
                          due_date: 1.day.from_now)
      end
      let!(:failing_task) do
        create(:crm_task, account: account, status: :pending,
                          reminded: false, reminder_at: 20.minutes.ago,
                          due_date: 1.day.from_now)
      end

      before do
        allow(Crm::Task).to receive_message_chain(:needs_reminder, :find_each).and_yield(failing_task).and_yield(valid_task)
        allow(failing_task).to receive(:update!).and_raise(StandardError, 'Notification service down')
      end

      it 'logs the error and continues processing other tasks' do
        allow(Rails.logger).to receive(:error)

        job.perform

        expect(Rails.logger).to have_received(:error).with(/CRM TaskReminderJob failed for task##{failing_task.id}/)
        expect(valid_task.reload.reminded).to be(true)
      end
    end
  end
end
