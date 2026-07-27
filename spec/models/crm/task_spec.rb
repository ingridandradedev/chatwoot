# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Task do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:contact) }
    it { is_expected.to belong_to(:assignee).class_name('User') }
    it { is_expected.to belong_to(:created_by).class_name('User') }
    it { is_expected.to belong_to(:completed_by).class_name('User').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:account_id) }
    it { is_expected.to validate_presence_of(:contact_id) }
    it { is_expected.to validate_presence_of(:assignee_id) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_presence_of(:due_date) }
    it { is_expected.to validate_presence_of(:priority) }

    describe '#reminder_before_due_date' do
      let(:task) { build(:crm_task, due_date: 5.days.from_now) }

      it 'is valid when reminder_at is blank' do
        task.reminder_at = nil
        expect(task).to be_valid
      end

      it 'is valid when reminder_at is before due_date' do
        task.reminder_at = 2.days.from_now
        expect(task).to be_valid
      end

      it 'is invalid when reminder_at equals due_date' do
        task.reminder_at = task.due_date
        expect(task).not_to be_valid
        expect(task.errors[:reminder_at]).to include('must be before due_date')
      end

      it 'is invalid when reminder_at is after due_date' do
        task.reminder_at = 6.days.from_now
        expect(task).not_to be_valid
        expect(task.errors[:reminder_at]).to include('must be before due_date')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, completed: 1, overdue: 2) }
  end

  describe '#complete!' do
    let(:task) { create(:crm_task, status: :pending) }
    let(:completing_user) { create(:user) }

    it 'transitions status to completed' do
      task.complete!(completing_user)
      expect(task.reload.status).to eq('completed')
    end

    it 'records completed_at timestamp' do
      freeze_time do
        task.complete!(completing_user)
        expect(task.reload.completed_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'records the completing user' do
      task.complete!(completing_user)
      expect(task.reload.completed_by).to eq(completing_user)
    end

    it 'creates a task_completed activity' do
      expect { task.complete!(completing_user) }.to change(Crm::Activity, :count).by(1)

      activity = Crm::Activity.last
      expect(activity.activity_type).to eq('task_completed')
      expect(activity.contact).to eq(task.contact)
      expect(activity.user).to eq(completing_user)
      expect(activity.description).to include(task.title)
    end

    it 'raises error when task is already completed' do
      task.complete!(completing_user)
      expect { task.complete!(completing_user) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#reopen!' do
    let(:task) { create(:crm_task, :completed) }

    it 'transitions status back to pending' do
      task.reopen!
      expect(task.reload.status).to eq('pending')
    end

    it 'clears completed_at' do
      task.reopen!
      expect(task.reload.completed_at).to be_nil
    end

    it 'clears completed_by' do
      task.reopen!
      expect(task.reload.completed_by).to be_nil
    end

    it 'raises error when task is not completed' do
      pending_task = create(:crm_task, status: :pending)
      expect { pending_task.reopen! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'scopes' do
    let(:account) { create(:account) }

    describe '.pending_and_overdue' do
      it 'returns tasks with pending or overdue status' do
        pending_task = create(:crm_task, account: account, status: :pending)
        overdue_task = create(:crm_task, :overdue, account: account)
        completed_task = create(:crm_task, :completed, account: account)

        results = Crm::Task.pending_and_overdue
        expect(results).to include(pending_task, overdue_task)
        expect(results).not_to include(completed_task)
      end
    end

    describe '.due_before' do
      it 'returns pending tasks with due_date before the given time' do
        past_due_task = create(:crm_task, account: account, status: :pending, due_date: 1.day.ago)
        future_task = create(:crm_task, account: account, status: :pending, due_date: 5.days.from_now)
        overdue_task = create(:crm_task, :overdue, account: account, due_date: 1.day.ago)

        results = Crm::Task.due_before(Time.current)
        expect(results).to include(past_due_task)
        expect(results).not_to include(future_task)
        expect(results).not_to include(overdue_task) # only pending status
      end
    end

    describe '.needs_reminder' do
      it 'returns pending tasks with reminder_at in the past and not yet reminded' do
        needs_reminder_task = create(:crm_task, account: account, status: :pending,
                                                due_date: 5.days.from_now,
                                                reminder_at: 1.hour.ago, reminded: false)
        already_reminded = create(:crm_task, account: account, status: :pending,
                                             due_date: 5.days.from_now,
                                             reminder_at: 1.hour.ago, reminded: true)
        future_reminder = create(:crm_task, account: account, status: :pending,
                                            due_date: 5.days.from_now,
                                            reminder_at: 1.day.from_now, reminded: false)

        results = Crm::Task.needs_reminder
        expect(results).to include(needs_reminder_task)
        expect(results).not_to include(already_reminded)
        expect(results).not_to include(future_reminder)
      end
    end
  end
end
