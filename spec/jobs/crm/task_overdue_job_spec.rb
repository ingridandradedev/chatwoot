require 'rails_helper'

RSpec.describe Crm::TaskOverdueJob do
  subject(:job) { described_class.new }

  let(:account) { create(:account) }

  it 'enqueues the job on scheduled_jobs queue' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  describe '#perform' do
    context 'when there are pending tasks with past due_date' do
      let!(:overdue_task) { create(:crm_task, account: account, due_date: 1.day.ago, status: :pending) }

      it 'marks them as overdue' do
        job.perform

        expect(overdue_task.reload.status).to eq('overdue')
      end
    end

    context 'when a task is already completed' do
      let!(:completed_task) { create(:crm_task, :completed, account: account, due_date: 2.days.ago) }

      it 'does not change its status' do
        job.perform

        expect(completed_task.reload.status).to eq('completed')
      end
    end

    context 'when a task is already overdue' do
      let!(:overdue_task) { create(:crm_task, :overdue, account: account) }

      it 'does not change its status' do
        expect { job.perform }.not_to(change { overdue_task.reload.updated_at })
      end
    end

    context 'when a pending task has a future due_date' do
      let!(:future_task) { create(:crm_task, account: account, due_date: 3.days.from_now, status: :pending) }

      it 'does not change its status' do
        job.perform

        expect(future_task.reload.status).to eq('pending')
      end
    end

    context 'when an individual task errors during update' do
      let!(:valid_task) { create(:crm_task, account: account, due_date: 1.day.ago, status: :pending) }
      let!(:failing_task) { create(:crm_task, account: account, due_date: 2.days.ago, status: :pending) }

      before do
        allow(failing_task).to receive(:update!).and_raise(StandardError, 'DB error')
        allow(Crm::Task).to receive_message_chain(:due_before, :find_each).and_yield(failing_task).and_yield(valid_task)
      end

      it 'logs the error and continues processing other tasks' do
        allow(Rails.logger).to receive(:error)

        job.perform

        expect(Rails.logger).to have_received(:error).with(/CRM TaskOverdueJob failed for task##{failing_task.id}/)
        expect(valid_task.reload.status).to eq('overdue')
      end
    end
  end
end
