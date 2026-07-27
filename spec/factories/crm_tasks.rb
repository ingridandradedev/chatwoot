# frozen_string_literal: true

FactoryBot.define do
  factory :crm_task, class: 'Crm::Task' do
    account
    title { 'Follow up with contact' }
    due_date { 3.days.from_now }
    priority { :medium }
    status { :pending }

    after(:build) do |task|
      task.contact ||= create(:contact, account: task.account)
      task.assignee ||= create(:user)
      task.created_by ||= create(:user)
    end

    trait :with_reminder do
      reminder_at { 2.days.from_now }
    end

    trait :completed do
      status { :completed }
      completed_at { Time.current }

      after(:build) do |task|
        task.completed_by ||= task.assignee
      end
    end

    trait :overdue do
      status { :overdue }
      due_date { 1.day.ago }
    end

    trait :high_priority do
      priority { :high }
    end
  end
end
