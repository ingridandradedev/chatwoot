# Technical Design Document — CRM Module

## Overview

This document describes the technical design for a lightweight CRM module integrated into a Chatwoot fork (Ruby on Rails 7.1 + Vue 3). The module delivers pipeline/Kanban management, an immutable activity log, and task management with reminders — all isolated in `Crm::` namespaces to minimize upstream merge conflicts.

## Architecture

The CRM module follows Chatwoot's existing layered architecture:

```
┌─────────────────────────────────────────────────────────┐
│  Frontend (Vue 3 + Pinia + vuedraggable)                │
│  app/javascript/dashboard/{routes,stores,api,components}/crm/ │
├─────────────────────────────────────────────────────────┤
│  API Layer (Rails Controllers + JBuilder Views)          │
│  app/controllers/api/v1/accounts/crm/*_controller.rb    │
│  app/views/api/v1/accounts/crm/**/*.json.jbuilder       │
├─────────────────────────────────────────────────────────┤
│  Authorization (Pundit Policies)                         │
│  app/policies/crm/*_policy.rb                            │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (Models + Services)                        │
│  app/models/crm/*.rb                                     │
├─────────────────────────────────────────────────────────┤
│  Background Jobs (Sidekiq)                               │
│  app/jobs/crm/*.rb                                       │
├─────────────────────────────────────────────────────────┤
│  Database (PostgreSQL)                                   │
│  crm_pipelines, crm_stages, crm_deals,                  │
│  crm_activities, crm_tasks                               │
└─────────────────────────────────────────────────────────┘
```

## Components and Interfaces

The CRM module consists of the following key components:

1. **Backend Models** (`Crm::Pipeline`, `Crm::Stage`, `Crm::Deal`, `Crm::Activity`, `Crm::Task`) — ActiveRecord models in `app/models/crm/`
2. **API Controllers** (`Api::V1::Accounts::Crm::*Controller`) — RESTful endpoints in `app/controllers/api/v1/accounts/crm/`
3. **Pundit Policies** (`Crm::*Policy`) — Authorization in `app/policies/crm/`
4. **Sidekiq Jobs** (`Crm::TaskOverdueJob`, `Crm::TaskReminderJob`) — Background processing in `app/jobs/crm/`
5. **JBuilder Views** — JSON response templates in `app/views/api/v1/accounts/crm/`
6. **Frontend API Clients** — Axios wrappers in `app/javascript/dashboard/api/crm/`
7. **Pinia Stores** — State management in `app/javascript/dashboard/stores/crm/`
8. **Vue Components** — UI in `app/javascript/dashboard/components/crm/` and `components-next/`
9. **Vue Routes** — Navigation in `app/javascript/dashboard/routes/dashboard/crm/`

## Data Models

### Entity Relationship Diagram

```
Account 1──* Crm::Pipeline 1──* Crm::Stage 1──* Crm::Deal *──1 Contact
                                                      │
Account 1──* Crm::Activity *──1 Contact               │
Account 1──* Crm::Task *──1 Contact                   │
                                                      │
User (Agent) ──────────────────────────────────────────┘
```

### Table: `crm_pipelines`

| Column       | Type         | Constraints          |
|-------------|-------------|---------------------|
| id          | bigint PK    | auto-increment       |
| account_id  | bigint       | NOT NULL, FK → accounts.id, INDEX |
| name        | varchar(255) | NOT NULL             |
| created_at  | datetime     | NOT NULL             |
| updated_at  | datetime     | NOT NULL             |

**Indexes:** `(account_id)`, `(account_id, name)` UNIQUE

### Table: `crm_stages`

| Column       | Type         | Constraints          |
|-------------|-------------|---------------------|
| id          | bigint PK    | auto-increment       |
| account_id  | bigint       | NOT NULL, FK → accounts.id, INDEX |
| pipeline_id | bigint       | NOT NULL, FK → crm_pipelines.id, INDEX |
| name        | varchar(255) | NOT NULL             |
| position    | integer      | NOT NULL, default 0  |
| created_at  | datetime     | NOT NULL             |
| updated_at  | datetime     | NOT NULL             |

**Indexes:** `(pipeline_id, position)`, `(account_id)`

### Table: `crm_deals`

| Column        | Type          | Constraints          |
|--------------|--------------|---------------------|
| id           | bigint PK     | auto-increment       |
| account_id   | bigint        | NOT NULL, FK → accounts.id, INDEX |
| contact_id   | bigint        | NOT NULL, FK → contacts.id, INDEX |
| stage_id     | bigint        | NOT NULL, FK → crm_stages.id, INDEX |
| title        | varchar(255)  | nullable             |
| value        | decimal(15,2) | nullable             |
| created_by_id| bigint        | NOT NULL, FK → users.id |
| created_at   | datetime      | NOT NULL             |
| updated_at   | datetime      | NOT NULL             |

**Indexes:** `(account_id)`, `(stage_id)`, `(contact_id)`, composite application-level uniqueness per pipeline

**Uniqueness Strategy:** Since the pipeline_id is on `crm_stages` not `crm_deals`, we add a unique index on `(contact_id, stage_id)` at DB level plus an application-level validation in `Crm::Deal` that checks no other deal exists for the same contact in any stage of the same pipeline.

### Table: `crm_activities`

| Column        | Type         | Constraints          |
|--------------|-------------|---------------------|
| id           | bigint PK    | auto-increment       |
| account_id   | bigint       | NOT NULL, FK → accounts.id, INDEX |
| contact_id   | bigint       | NOT NULL, FK → contacts.id, INDEX |
| user_id      | bigint       | NOT NULL, FK → users.id |
| activity_type| integer      | NOT NULL (enum)      |
| description  | text         | NOT NULL             |
| metadata     | jsonb        | NOT NULL, default '{}' |
| created_at   | datetime     | NOT NULL             |

**No `updated_at`** — activities are immutable.

**Indexes:** `(account_id)`, `(contact_id, created_at DESC)`

**Enum mapping:** `{ call: 0, email: 1, meeting: 2, note: 3, stage_change: 4, task_completed: 5 }`

### Table: `crm_tasks`

| Column         | Type         | Constraints          |
|---------------|-------------|---------------------|
| id            | bigint PK    | auto-increment       |
| account_id    | bigint       | NOT NULL, FK → accounts.id, INDEX |
| contact_id    | bigint       | NOT NULL, FK → contacts.id, INDEX |
| assignee_id   | bigint       | NOT NULL, FK → users.id, INDEX |
| created_by_id | bigint       | NOT NULL, FK → users.id |
| title         | varchar(255) | NOT NULL             |
| description   | text         | nullable             |
| due_date      | datetime     | NOT NULL             |
| reminder_at   | datetime     | nullable             |
| reminded      | boolean      | NOT NULL, default false |
| priority      | integer      | NOT NULL, default 0 (enum) |
| status        | integer      | NOT NULL, default 0 (enum) |
| completed_at  | datetime     | nullable             |
| completed_by_id| bigint      | nullable, FK → users.id |
| created_at    | datetime     | NOT NULL             |
| updated_at    | datetime     | NOT NULL             |

**Indexes:** `(account_id)`, `(contact_id)`, `(assignee_id)`, `(status, due_date)` for overdue job, `(reminded, reminder_at, status)` for reminder job

**Enum mappings:**
- priority: `{ low: 0, medium: 1, high: 2 }`
- status: `{ pending: 0, completed: 1, overdue: 2 }`

---

## Backend Design

### Models (`app/models/crm/`)

All models are namespaced under `Crm::` and placed in `app/models/crm/`. Each model sets its own `self.table_name` explicitly.

#### `Crm::Pipeline` (`app/models/crm/pipeline.rb`)

```ruby
module Crm
  class Pipeline < ApplicationRecord
    self.table_name = 'crm_pipelines'

    belongs_to :account
    has_many :stages, class_name: 'Crm::Stage', dependent: :restrict_with_error
    has_many :deals, through: :stages

    validates :name, presence: true, length: { maximum: 255 },
                     uniqueness: { scope: :account_id }
    validates :account_id, presence: true

    after_create :create_default_stages

    private

    def create_default_stages
      %w[Novo Qualificando Proposta].each_with_index do |name, i|
        stages.create!(name: name, position: i + 1, account: account)
      end
      stages.create!(name: 'Fechado Ganho', position: 4, account: account)
      stages.create!(name: 'Fechado Perdido', position: 5, account: account)
    end
  end
end
```

#### `Crm::Stage` (`app/models/crm/stage.rb`)

```ruby
module Crm
  class Stage < ApplicationRecord
    self.table_name = 'crm_stages'

    belongs_to :account
    belongs_to :pipeline, class_name: 'Crm::Pipeline'
    has_many :deals, class_name: 'Crm::Deal', dependent: :restrict_with_error

    validates :name, presence: true, length: { maximum: 255 }
    validates :position, presence: true, numericality: { only_integer: true }
    validates :account_id, presence: true

    scope :ordered, -> { order(position: :asc) }
  end
end
```

#### `Crm::Deal` (`app/models/crm/deal.rb`)

```ruby
module Crm
  class Deal < ApplicationRecord
    self.table_name = 'crm_deals'

    belongs_to :account
    belongs_to :contact
    belongs_to :stage, class_name: 'Crm::Stage'
    belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'

    validates :account_id, presence: true
    validates :contact_id, presence: true
    validates :stage_id, presence: true
    validates :title, length: { maximum: 255 }, allow_blank: true
    validates :value, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000_000 }, allow_nil: true
    validate :one_deal_per_contact_per_pipeline

    private

    def one_deal_per_contact_per_pipeline
      return unless contact_id && stage_id

      pipeline_id = stage&.pipeline_id
      existing = self.class.joins(:stage)
                     .where(contact_id: contact_id, crm_stages: { pipeline_id: pipeline_id })
                     .where.not(id: id)
      errors.add(:contact_id, 'already has a deal in this pipeline') if existing.exists?
    end
  end
end
```

#### `Crm::Activity` (`app/models/crm/activity.rb`)

```ruby
module Crm
  class Activity < ApplicationRecord
    self.table_name = 'crm_activities'

    belongs_to :account
    belongs_to :contact
    belongs_to :user

    enum activity_type: { call: 0, email: 1, meeting: 2, note: 3, stage_change: 4, task_completed: 5 }

    MANUAL_TYPES = %w[call email meeting note].freeze
    SYSTEM_TYPES = %w[stage_change task_completed].freeze

    validates :account_id, presence: true
    validates :contact_id, presence: true
    validates :user_id, presence: true
    validates :activity_type, presence: true
    validates :description, presence: true, length: { maximum: 10_000 }

    # Immutable: no updates allowed
    def readonly?
      persisted?
    end

    scope :recent_first, -> { order(created_at: :desc) }
  end
end
```

#### `Crm::Task` (`app/models/crm/task.rb`)

```ruby
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
```

### Controllers (`app/controllers/api/v1/accounts/crm/`)

All CRM controllers inherit from a shared base controller that inherits from Chatwoot's existing `Api::V1::Accounts::BaseController`.

#### Base Controller

```ruby
# app/controllers/api/v1/accounts/crm/base_controller.rb
module Api::V1::Accounts::Crm
  class BaseController < Api::V1::Accounts::BaseController
    before_action :check_authorization

    private

    def crm_pipelines
      Current.account.crm_pipelines
    end
  end
end
```

#### Pipelines Controller

```ruby
# app/controllers/api/v1/accounts/crm/pipelines_controller.rb
module Api::V1::Accounts::Crm
  class PipelinesController < BaseController
    before_action :set_pipeline, only: [:show, :update, :destroy]

    def index
      @pipelines = policy_scope(Crm::Pipeline).where(account: Current.account)
    end

    def show; end

    def create
      @pipeline = Current.account.crm_pipelines.new(pipeline_params)
      authorize @pipeline
      @pipeline.save!
    end

    def update
      authorize @pipeline
      @pipeline.update!(pipeline_params)
    end

    def destroy
      authorize @pipeline
      @pipeline.destroy!
    end

    private

    def set_pipeline
      @pipeline = crm_pipelines.find(params[:id])
    end

    def pipeline_params
      params.require(:pipeline).permit(:name)
    end
  end
end
```

#### Stages Controller

```ruby
# app/controllers/api/v1/accounts/crm/stages_controller.rb
module Api::V1::Accounts::Crm
  class StagesController < BaseController
    before_action :set_pipeline
    before_action :set_stage, only: [:update, :destroy]

    def index
      @stages = @pipeline.stages.ordered
    end

    def create
      @stage = @pipeline.stages.new(stage_params.merge(account: Current.account))
      authorize @stage, policy_class: Crm::StagePolicy
      @stage.save!
    end

    def update
      authorize @stage, policy_class: Crm::StagePolicy
      @stage.update!(stage_params)
    end

    def destroy
      authorize @stage, policy_class: Crm::StagePolicy
      if @stage.deals.exists?
        render json: { error: 'Reassign deals before deleting' }, status: :unprocessable_entity
        return
      end
      @stage.destroy!
    end

    def reorder
      authorize @pipeline, :update?, policy_class: Crm::PipelinePolicy
      params[:positions].each do |pos|
        @pipeline.stages.find(pos[:id]).update!(position: pos[:position])
      end
      head :ok
    end

    private

    def set_pipeline
      @pipeline = crm_pipelines.find(params[:pipeline_id])
    end

    def set_stage
      @stage = @pipeline.stages.find(params[:id])
    end

    def stage_params
      params.require(:stage).permit(:name, :position)
    end
  end
end
```

#### Deals Controller

```ruby
# app/controllers/api/v1/accounts/crm/deals_controller.rb
module Api::V1::Accounts::Crm
  class DealsController < BaseController
    before_action :set_pipeline
    before_action :set_deal, only: [:show, :update, :destroy]

    def index
      @deals = @pipeline.deals.where(account: Current.account)
      @deals = @deals.where(stage_id: params[:stage_id]) if params[:stage_id].present?
      @deals = @deals.includes(:contact, :stage).page(params[:page]).per(15)
    end

    def show; end

    def create
      @deal = Crm::Deal.new(deal_params.merge(
        account: Current.account, created_by: current_user
      ))
      authorize @deal
      @deal.save!
    end

    def update
      authorize @deal
      old_stage_id = @deal.stage_id
      @deal.update!(deal_params)
      create_stage_change_activity(old_stage_id) if old_stage_id != @deal.stage_id
    end

    def destroy
      authorize @deal
      @deal.destroy!
      head :ok
    end

    private

    def set_pipeline
      @pipeline = crm_pipelines.find(params[:pipeline_id])
    end

    def set_deal
      @deal = @pipeline.deals.find(params[:id])
    end

    def deal_params
      params.require(:deal).permit(:contact_id, :stage_id, :title, :value)
    end

    def create_stage_change_activity(old_stage_id)
      old_stage = Crm::Stage.find(old_stage_id)
      new_stage = @deal.stage
      Crm::Activity.create!(
        account: Current.account,
        contact: @deal.contact,
        user: current_user,
        activity_type: :stage_change,
        description: "Movido de '#{old_stage.name}' para '#{new_stage.name}'",
        metadata: { from_stage_id: old_stage_id, to_stage_id: new_stage.id }
      )
    end
  end
end
```

#### Activities Controller

```ruby
# app/controllers/api/v1/accounts/crm/activities_controller.rb
module Api::V1::Accounts::Crm
  class ActivitiesController < BaseController
    before_action :set_contact

    def index
      @activities = @contact.crm_activities
                            .where(account: Current.account)
                            .recent_first
                            .page(params[:page]).per(20)
    end

    def create
      unless Crm::Activity::MANUAL_TYPES.include?(params[:activity][:activity_type])
        render json: { error: 'Only manual types allowed' }, status: :unprocessable_entity
        return
      end
      @activity = Crm::Activity.new(activity_params.merge(
        account: Current.account, user: current_user, contact: @contact
      ))
      authorize @activity
      @activity.save!
    end

    private

    def set_contact
      @contact = Current.account.contacts.find(params[:contact_id])
    end

    def activity_params
      params.require(:activity).permit(:activity_type, :description)
    end
  end
end
```

#### Tasks Controller

```ruby
# app/controllers/api/v1/accounts/crm/tasks_controller.rb
module Api::V1::Accounts::Crm
  class TasksController < BaseController
    before_action :set_contact, only: [:index_for_contact, :create]
    before_action :set_task, only: [:show, :update, :destroy, :complete, :reopen]

    # GET /crm/contacts/:contact_id/tasks
    def index_for_contact
      @tasks = @contact.crm_tasks
                       .where(account: Current.account)
                       .pending_and_overdue
                       .order(due_date: :asc)
                       .page(params[:page]).per(15)
    end

    # GET /crm/tasks
    def index
      @tasks = Crm::Task.where(account: Current.account)
      @tasks = @tasks.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
      @tasks = @tasks.where(status: params[:status]) if params[:status].present?
      @tasks = @tasks.order(due_date: :asc).page(params[:page]).per(15)
    end

    def show; end

    def create
      @task = Crm::Task.new(task_params.merge(
        account: Current.account, created_by: current_user, contact: @contact
      ))
      authorize @task
      @task.save!
    end

    def update
      authorize @task
      if @task.completed?
        render json: { error: 'Cannot edit completed task' }, status: :unprocessable_entity
        return
      end
      old_status = @task.status
      @task.update!(task_params)
      # If due_date extended on overdue task, reset to pending
      @task.update!(status: :pending) if old_status == 'overdue' && @task.due_date > Time.current
      # Reset reminded if reminder_at changed
      @task.update!(reminded: false) if task_params[:reminder_at].present?
    end

    def destroy
      authorize @task
      @task.destroy!
      head :ok
    end

    # POST /crm/tasks/:id/complete
    def complete
      authorize @task, :update?
      @task.complete!(current_user)
    end

    # POST /crm/tasks/:id/reopen
    def reopen
      authorize @task, :update?
      @task.reopen!
    end

    private

    def set_contact
      @contact = Current.account.contacts.find(params[:contact_id])
    end

    def set_task
      @task = Crm::Task.where(account: Current.account).find(params[:id])
    end

    def task_params
      params.require(:task).permit(:title, :description, :assignee_id,
                                   :due_date, :reminder_at, :priority)
    end
  end
end
```

### Routes

Added to `config/routes.rb` inside the existing `scope module: :accounts do` block, after the `companies` resource:

```ruby
# CRM Module routes
namespace :crm do
  resources :pipelines, only: [:index, :show, :create, :update, :destroy] do
    resources :stages, only: [:index, :create, :update, :destroy] do
      collection do
        post :reorder
      end
    end
    resources :deals, only: [:index, :show, :create, :update, :destroy]
  end
  resources :contacts, only: [] do
    resources :activities, only: [:index, :create]
    resources :tasks, only: [:index, :create], controller: 'tasks', action_suffix: '_for_contact'
  end
  resources :tasks, only: [:index, :show, :update, :destroy] do
    member do
      post :complete
      post :reopen
    end
  end
end
```

**Resulting API paths:**
- `GET/POST /api/v1/accounts/:account_id/crm/pipelines`
- `GET/PATCH/DELETE /api/v1/accounts/:account_id/crm/pipelines/:id`
- `GET/POST /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages`
- `PATCH/DELETE /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages/:id`
- `POST /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/stages/reorder`
- `GET/POST /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/deals`
- `GET/PATCH/DELETE /api/v1/accounts/:account_id/crm/pipelines/:pipeline_id/deals/:id`
- `GET/POST /api/v1/accounts/:account_id/crm/contacts/:contact_id/activities`
- `GET/POST /api/v1/accounts/:account_id/crm/contacts/:contact_id/tasks`
- `GET /api/v1/accounts/:account_id/crm/tasks`
- `GET/PATCH/DELETE /api/v1/accounts/:account_id/crm/tasks/:id`
- `POST /api/v1/accounts/:account_id/crm/tasks/:id/complete`
- `POST /api/v1/accounts/:account_id/crm/tasks/:id/reopen`

### Policies (`app/policies/crm/`)

#### Pipeline Policy

```ruby
# app/policies/crm/pipeline_policy.rb
module Crm
  class PipelinePolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      @account_user.administrator?
    end

    def update?
      @account_user.administrator?
    end

    def destroy?
      @account_user.administrator?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(account_id: @account.id)
      end
    end
  end
end
```

#### Deal Policy

```ruby
# app/policies/crm/deal_policy.rb
module Crm
  class DealPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      true
    end

    def update?
      true
    end

    def destroy?
      @account_user.administrator?
    end
  end
end
```

#### Activity Policy

```ruby
# app/policies/crm/activity_policy.rb
module Crm
  class ActivityPolicy < ApplicationPolicy
    def index?
      true
    end

    def create?
      true
    end

    # No update or destroy — activities are immutable
  end
end
```

#### Task Policy

```ruby
# app/policies/crm/task_policy.rb
module Crm
  class TaskPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      true
    end

    def update?
      true
    end

    def destroy?
      @account_user.administrator? || record.created_by_id == @user.id
    end
  end
end
```

### Background Jobs (`app/jobs/crm/`)

#### Task Overdue Job

```ruby
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
```

#### Task Reminder Job

```ruby
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
```

**Note:** A new `notification_type` value (`crm_task_reminder: 9`) will be added to the `Notification::NOTIFICATION_TYPES` hash. This is a minimal 1-line additive change to the upstream model.

#### Schedule Configuration (`config/schedule.yml` additions)

```yaml
# CRM: Mark overdue tasks every 15 minutes
crm_task_overdue_job:
  cron: '*/15 * * * *'
  class: 'Crm::TaskOverdueJob'
  queue: scheduled_jobs

# CRM: Process task reminders every 5 minutes
crm_task_reminder_job:
  cron: '*/5 * * * *'
  class: 'Crm::TaskReminderJob'
  queue: scheduled_jobs
```

### JBuilder Views (`app/views/api/v1/accounts/crm/`)

Following Chatwoot's pattern of `index.json.jbuilder` + shared partials:

```
app/views/api/v1/accounts/crm/
├── pipelines/
│   ├── index.json.jbuilder
│   ├── show.json.jbuilder
│   └── _pipeline.json.jbuilder
├── stages/
│   ├── index.json.jbuilder
│   └── _stage.json.jbuilder
├── deals/
│   ├── index.json.jbuilder
│   ├── show.json.jbuilder
│   └── _deal.json.jbuilder
├── activities/
│   ├── index.json.jbuilder
│   ├── create.json.jbuilder
│   └── _activity.json.jbuilder
└── tasks/
    ├── index.json.jbuilder
    ├── show.json.jbuilder
    ├── create.json.jbuilder
    └── _task.json.jbuilder
```

**Example — `deals/index.json.jbuilder`:**
```ruby
json.meta do
  json.count @deals.total_count
  json.current_page @deals.current_page
end

json.payload do
  json.array! @deals do |deal|
    json.partial! 'api/v1/accounts/crm/deals/deal', deal: deal
  end
end
```

**Example — `deals/_deal.json.jbuilder`:**
```ruby
json.id deal.id
json.title deal.title
json.value deal.value.to_f
json.stage_id deal.stage_id
json.contact do
  json.id deal.contact.id
  json.name deal.contact.name
  json.email deal.contact.email
  json.thumbnail deal.contact.avatar_url
end
json.created_by_id deal.created_by_id
json.created_at deal.created_at.to_i
json.updated_at deal.updated_at.to_i
```

---

## Frontend Design

### Directory Structure

```
app/javascript/dashboard/
├── api/crm/
│   ├── pipelines.js
│   ├── deals.js
│   ├── activities.js
│   └── tasks.js
├── stores/crm/
│   ├── pipelines.js
│   ├── deals.js
│   ├── activities.js
│   └── tasks.js
├── routes/dashboard/crm/
│   ├── routes.js
│   └── pages/
│       ├── CrmIndex.vue         (Kanban board)
│       └── PipelineSettings.vue (Pipeline CRUD)
├── components/crm/
│   ├── KanbanBoard.vue
│   ├── KanbanColumn.vue
│   ├── DealCard.vue
│   ├── DealFormModal.vue
│   ├── ActivityTimeline.vue
│   ├── ActivityForm.vue
│   ├── TaskList.vue
│   ├── TaskCard.vue
│   └── TaskFormModal.vue
└── components-next/Contacts/ContactsSidebar/
    ├── ContactCrmActivities.vue  (new tab component)
    └── ContactCrmTasks.vue       (new tab component)
```

### API Clients (`app/javascript/dashboard/api/crm/`)

Following the existing `ApiClient` pattern with `accountScoped: true`:

```javascript
// api/crm/pipelines.js
import ApiClient from '../ApiClient';

class PipelineAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
  }
}

export default new PipelineAPI();
```

```javascript
// api/crm/deals.js
import ApiClient from '../ApiClient';

class DealAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
  }

  getForPipeline(pipelineId, params = {}) {
    return axios.get(`${this.url}/${pipelineId}/deals`, { params });
  }

  moveToStage(pipelineId, dealId, stageId) {
    return axios.patch(`${this.url}/${pipelineId}/deals/${dealId}`, {
      deal: { stage_id: stageId },
    });
  }
}

export default new DealAPI();
```

```javascript
// api/crm/activities.js
import ApiClient from '../ApiClient';

class ActivityAPI extends ApiClient {
  constructor() {
    super('crm/contacts', { accountScoped: true });
  }

  getForContact(contactId, page = 1) {
    return axios.get(`${this.url}/${contactId}/activities`, { params: { page } });
  }

  createForContact(contactId, data) {
    return axios.post(`${this.url}/${contactId}/activities`, { activity: data });
  }
}

export default new ActivityAPI();
```

```javascript
// api/crm/tasks.js
import ApiClient from '../ApiClient';

class TaskAPI extends ApiClient {
  constructor() {
    super('crm/tasks', { accountScoped: true });
  }

  getForContact(contactId, page = 1) {
    const baseUrl = this.baseUrl();
    return axios.get(`${baseUrl}/crm/contacts/${contactId}/tasks`, { params: { page } });
  }

  createForContact(contactId, data) {
    const baseUrl = this.baseUrl();
    return axios.post(`${baseUrl}/crm/contacts/${contactId}/tasks`, { task: data });
  }

  complete(taskId) {
    return axios.post(`${this.url}/${taskId}/complete`);
  }

  reopen(taskId) {
    return axios.post(`${this.url}/${taskId}/reopen`);
  }
}

export default new TaskAPI();
```

### Pinia Stores (`app/javascript/dashboard/stores/crm/`)

Using `createStore({ type: 'pinia' })` from the existing store factory:

```javascript
// stores/crm/pipelines.js
import PipelineAPI from 'dashboard/api/crm/pipelines';
import { createStore } from 'dashboard/store/storeFactory';

export const useCrmPipelinesStore = createStore({
  name: 'crmPipelines',
  type: 'pinia',
  API: PipelineAPI,
});
```

```javascript
// stores/crm/deals.js
import { defineStore } from 'pinia';
import DealAPI from 'dashboard/api/crm/deals';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useCrmDealsStore = defineStore('crmDeals', {
  state: () => ({
    dealsByStage: {},  // { stageId: [deal, deal, ...] }
    uiFlags: { fetchingList: false, updatingItem: false, creatingItem: false },
  }),

  getters: {
    getDealsForStage: state => stageId => state.dealsByStage[stageId] || [],
  },

  actions: {
    async fetchForPipeline(pipelineId) {
      this.uiFlags.fetchingList = true;
      try {
        const { data: { payload } } = await DealAPI.getForPipeline(pipelineId);
        // Group by stage_id
        this.dealsByStage = payload.reduce((acc, deal) => {
          (acc[deal.stage_id] ||= []).push(deal);
          return acc;
        }, {});
      } catch (e) { throwErrorMessage(e); }
      finally { this.uiFlags.fetchingList = false; }
    },

    async moveToStage(pipelineId, dealId, fromStageId, toStageId) {
      // Optimistic update
      const deal = this.dealsByStage[fromStageId]?.find(d => d.id === dealId);
      if (!deal) return;
      this.dealsByStage[fromStageId] = this.dealsByStage[fromStageId].filter(d => d.id !== dealId);
      (this.dealsByStage[toStageId] ||= []).push({ ...deal, stage_id: toStageId });

      try {
        await DealAPI.moveToStage(pipelineId, dealId, toStageId);
      } catch (e) {
        // Revert on failure
        this.dealsByStage[toStageId] = this.dealsByStage[toStageId].filter(d => d.id !== dealId);
        (this.dealsByStage[fromStageId] ||= []).push(deal);
        throwErrorMessage(e);
      }
    },
  },
});
```

### Frontend Routes (`app/javascript/dashboard/routes/dashboard/crm/routes.js`)

```javascript
import { frontendURL } from '../../../helper/URLHelper';

const CrmIndex = () => import('./pages/CrmIndex.vue');
const PipelineSettings = () => import('./pages/PipelineSettings.vue');

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    name: 'crm_dashboard_index',
    component: CrmIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/pipelines/:pipelineId'),
    name: 'crm_pipeline_board',
    component: CrmIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/settings'),
    name: 'crm_pipeline_settings',
    component: PipelineSettings,
    meta: { permissions: ['administrator'] },
  },
];
```

**Registration in `dashboard.routes.js`** (1 line added):
```javascript
import { routes as crmRoutes } from './crm/routes';
// ... in children array:
...crmRoutes,
```

### Sidebar Integration

In `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`, add after the "Companies" entry (additive-only, ~8 lines):

```javascript
{
  name: 'CRM',
  label: t('SIDEBAR.CRM'),
  icon: 'i-lucide-kanban',
  children: [
    {
      name: 'CRM Board',
      label: t('SIDEBAR.CRM_BOARD'),
      to: accountScopedRoute('crm_dashboard_index'),
      activeOn: ['crm_dashboard_index', 'crm_pipeline_board'],
    },
    {
      name: 'CRM Settings',
      label: t('SIDEBAR.CRM_SETTINGS'),
      to: accountScopedRoute('crm_pipeline_settings'),
      activeOn: ['crm_pipeline_settings'],
    },
  ],
},
```

### Contact Detail Tabs Integration

In `ContactManageView.vue`, add 2 entries to the `CONTACT_TABS_OPTIONS` array:

```javascript
const CONTACT_TABS_OPTIONS = [
  { key: 'ATTRIBUTES', value: 'attributes' },
  { key: 'HISTORY', value: 'history' },
  { key: 'NOTES', value: 'notes' },
  { key: 'MEDIA', value: 'media' },
  { key: 'MERGE', value: 'merge' },
  // CRM additions
  { key: 'CRM_ACTIVITIES', value: 'crm_activities' },
  { key: 'CRM_TASKS', value: 'crm_tasks' },
];
```

And in the template's `<template #sidebar>`:

```vue
<ContactCrmActivities
  v-if="activeTab === 'crm_activities'"
  :contact-id="route.params.contactId"
/>
<ContactCrmTasks
  v-if="activeTab === 'crm_tasks'"
  :contact-id="route.params.contactId"
/>
```

### Key Component: KanbanBoard.vue

```vue
<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useCrmPipelinesStore } from 'dashboard/stores/crm/pipelines';
import { useCrmDealsStore } from 'dashboard/stores/crm/deals';
import draggable from 'vuedraggable';
import KanbanColumn from './KanbanColumn.vue';

const pipelineStore = useCrmPipelinesStore();
const dealStore = useCrmDealsStore();

const selectedPipelineId = ref(null);
const pipelines = computed(() => pipelineStore.getRecords);
const selectedPipeline = computed(() =>
  pipelines.value.find(p => p.id === selectedPipelineId.value)
);
const stages = computed(() => selectedPipeline.value?.stages || []);

onMounted(async () => {
  await pipelineStore.get();
  if (pipelines.value.length) {
    selectedPipelineId.value = pipelines.value[0].id;
  }
});

watch(selectedPipelineId, async (id) => {
  if (id) await dealStore.fetchForPipeline(id);
});

const onDealMoved = ({ dealId, fromStageId, toStageId }) => {
  dealStore.moveToStage(selectedPipelineId.value, dealId, fromStageId, toStageId);
};
</script>

<template>
  <div class="flex flex-col h-full">
    <!-- Pipeline selector -->
    <header class="flex items-center gap-3 px-6 py-4 border-b">
      <select v-model="selectedPipelineId" class="...">
        <option v-for="p in pipelines" :key="p.id" :value="p.id">
          {{ p.name }}
        </option>
      </select>
    </header>
    <!-- Board -->
    <div class="flex flex-1 gap-4 p-4 overflow-x-auto">
      <KanbanColumn
        v-for="stage in stages"
        :key="stage.id"
        :stage="stage"
        :deals="dealStore.getDealsForStage(stage.id)"
        @deal-moved="onDealMoved"
      />
    </div>
  </div>
</template>
```

### Key Component: KanbanColumn.vue

Uses `vuedraggable` for drag-and-drop between columns:

```vue
<script setup>
import draggable from 'vuedraggable';
import DealCard from './DealCard.vue';

const props = defineProps({
  stage: { type: Object, required: true },
  deals: { type: Array, default: () => [] },
});

const emit = defineEmits(['deal-moved']);

const onDragEnd = (evt) => {
  if (evt.to !== evt.from || evt.oldIndex !== evt.newIndex) {
    const dealId = Number(evt.item.dataset.dealId);
    const toStageId = Number(evt.to.dataset.stageId);
    const fromStageId = props.stage.id;
    if (fromStageId !== toStageId) {
      emit('deal-moved', { dealId, fromStageId, toStageId });
    }
  }
};
</script>

<template>
  <div class="flex flex-col w-72 min-w-[288px] bg-n-alpha-black2 rounded-lg">
    <header class="px-3 py-2 font-medium text-sm border-b">
      {{ stage.name }} ({{ deals.length }})
    </header>
    <draggable
      :list="deals"
      group="deals"
      item-key="id"
      :data-stage-id="stage.id"
      class="flex-1 p-2 space-y-2 overflow-y-auto"
      @end="onDragEnd"
    >
      <template #item="{ element }">
        <DealCard :deal="element" />
      </template>
    </draggable>
  </div>
</template>
```

---

## Migrations

### Migration 1: Create CRM Pipelines and Stages

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_crm_pipelines_and_stages.rb
class CreateCrmPipelinesAndStages < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_pipelines do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 255
      t.timestamps
    end
    add_index :crm_pipelines, [:account_id, :name], unique: true

    create_table :crm_stages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: { to_table: :crm_pipelines }
      t.string :name, null: false, limit: 255
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :crm_stages, [:pipeline_id, :position]
  end
end
```

### Migration 2: Create CRM Deals

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_crm_deals.rb
class CreateCrmDeals < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_deals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :stage, null: false, foreign_key: { to_table: :crm_stages }
      t.string :title, limit: 255
      t.decimal :value, precision: 15, scale: 2
      t.bigint :created_by_id, null: false
      t.timestamps
    end
    add_foreign_key :crm_deals, :users, column: :created_by_id
    add_index :crm_deals, [:contact_id, :stage_id], unique: true
    add_index :crm_deals, :account_id
  end
end
```

### Migration 3: Create CRM Activities

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_crm_activities.rb
class CreateCrmActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_activities do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :activity_type, null: false
      t.text :description, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :crm_activities, [:contact_id, :created_at]
    add_index :crm_activities, :account_id
  end
end
```

### Migration 4: Create CRM Tasks

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_crm_tasks.rb
class CreateCrmTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.bigint :assignee_id, null: false
      t.bigint :created_by_id, null: false
      t.string :title, null: false, limit: 255
      t.text :description
      t.datetime :due_date, null: false
      t.datetime :reminder_at
      t.boolean :reminded, null: false, default: false
      t.integer :priority, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :completed_at
      t.bigint :completed_by_id
      t.timestamps
    end
    add_foreign_key :crm_tasks, :users, column: :assignee_id
    add_foreign_key :crm_tasks, :users, column: :created_by_id
    add_foreign_key :crm_tasks, :users, column: :completed_by_id
    add_index :crm_tasks, :assignee_id
    add_index :crm_tasks, [:status, :due_date]
    add_index :crm_tasks, [:reminded, :reminder_at, :status]
    add_index :crm_tasks, :account_id
  end
end
```

---

## Files Created (New)

### Backend
| Path | Purpose |
|------|---------|
| `app/models/crm/pipeline.rb` | Pipeline model |
| `app/models/crm/stage.rb` | Stage model |
| `app/models/crm/deal.rb` | Deal model |
| `app/models/crm/activity.rb` | Activity model |
| `app/models/crm/task.rb` | Task model |
| `app/controllers/api/v1/accounts/crm/base_controller.rb` | CRM base controller |
| `app/controllers/api/v1/accounts/crm/pipelines_controller.rb` | Pipelines CRUD |
| `app/controllers/api/v1/accounts/crm/stages_controller.rb` | Stages CRUD + reorder |
| `app/controllers/api/v1/accounts/crm/deals_controller.rb` | Deals CRUD |
| `app/controllers/api/v1/accounts/crm/activities_controller.rb` | Activities index + create |
| `app/controllers/api/v1/accounts/crm/tasks_controller.rb` | Tasks CRUD + complete/reopen |
| `app/policies/crm/pipeline_policy.rb` | Pipeline authorization |
| `app/policies/crm/stage_policy.rb` | Stage authorization |
| `app/policies/crm/deal_policy.rb` | Deal authorization |
| `app/policies/crm/activity_policy.rb` | Activity authorization |
| `app/policies/crm/task_policy.rb` | Task authorization |
| `app/jobs/crm/task_overdue_job.rb` | Overdue detection cron |
| `app/jobs/crm/task_reminder_job.rb` | Reminder notification cron |
| `app/views/api/v1/accounts/crm/pipelines/*.json.jbuilder` | Pipeline views |
| `app/views/api/v1/accounts/crm/stages/*.json.jbuilder` | Stage views |
| `app/views/api/v1/accounts/crm/deals/*.json.jbuilder` | Deal views |
| `app/views/api/v1/accounts/crm/activities/*.json.jbuilder` | Activity views |
| `app/views/api/v1/accounts/crm/tasks/*.json.jbuilder` | Task views |
| `db/migrate/*_create_crm_pipelines_and_stages.rb` | Migration 1 |
| `db/migrate/*_create_crm_deals.rb` | Migration 2 |
| `db/migrate/*_create_crm_activities.rb` | Migration 3 |
| `db/migrate/*_create_crm_tasks.rb` | Migration 4 |
| `spec/models/crm/pipeline_spec.rb` | Pipeline model spec |
| `spec/models/crm/stage_spec.rb` | Stage model spec |
| `spec/models/crm/deal_spec.rb` | Deal model spec |
| `spec/models/crm/activity_spec.rb` | Activity model spec |
| `spec/models/crm/task_spec.rb` | Task model spec |
| `spec/requests/api/v1/accounts/crm/*_spec.rb` | Request specs (5 files) |
| `spec/factories/crm_pipelines.rb` | Factory |
| `spec/factories/crm_stages.rb` | Factory |
| `spec/factories/crm_deals.rb` | Factory |
| `spec/factories/crm_activities.rb` | Factory |
| `spec/factories/crm_tasks.rb` | Factory |
| `spec/jobs/crm/task_overdue_job_spec.rb` | Job spec |
| `spec/jobs/crm/task_reminder_job_spec.rb` | Job spec |

### Frontend (New)
| Path | Purpose |
|------|---------|
| `app/javascript/dashboard/api/crm/pipelines.js` | Pipeline API client |
| `app/javascript/dashboard/api/crm/deals.js` | Deal API client |
| `app/javascript/dashboard/api/crm/activities.js` | Activity API client |
| `app/javascript/dashboard/api/crm/tasks.js` | Task API client |
| `app/javascript/dashboard/stores/crm/pipelines.js` | Pipeline Pinia store |
| `app/javascript/dashboard/stores/crm/deals.js` | Deal Pinia store |
| `app/javascript/dashboard/stores/crm/activities.js` | Activity Pinia store |
| `app/javascript/dashboard/stores/crm/tasks.js` | Task Pinia store |
| `app/javascript/dashboard/routes/dashboard/crm/routes.js` | CRM routes |
| `app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndex.vue` | Kanban board page |
| `app/javascript/dashboard/routes/dashboard/crm/pages/PipelineSettings.vue` | Settings page |
| `app/javascript/dashboard/components/crm/KanbanBoard.vue` | Main board component |
| `app/javascript/dashboard/components/crm/KanbanColumn.vue` | Column component |
| `app/javascript/dashboard/components/crm/DealCard.vue` | Card component |
| `app/javascript/dashboard/components/crm/DealFormModal.vue` | Deal form modal |
| `app/javascript/dashboard/components/crm/ActivityTimeline.vue` | Activity list |
| `app/javascript/dashboard/components/crm/ActivityForm.vue` | Activity creation form |
| `app/javascript/dashboard/components/crm/TaskList.vue` | Task list |
| `app/javascript/dashboard/components/crm/TaskCard.vue` | Single task card |
| `app/javascript/dashboard/components/crm/TaskFormModal.vue` | Task form modal |
| `app/javascript/dashboard/components-next/Contacts/ContactsSidebar/ContactCrmActivities.vue` | Activities tab |
| `app/javascript/dashboard/components-next/Contacts/ContactsSidebar/ContactCrmTasks.vue` | Tasks tab |

## Files Modified (Existing — minimal changes)

| File | Change | Lines |
|------|--------|-------|
| `config/routes.rb` | Add `namespace :crm do...end` block inside account scope | ~25 lines (isolated block) |
| `config/schedule.yml` | Add 2 cron entries for CRM jobs | 8 lines |
| `app/models/notification.rb` | Add `crm_task_reminder: 9` to NOTIFICATION_TYPES | 1 line |
| `app/models/account.rb` | Add `has_many :crm_pipelines` association | 1 line |
| `app/models/contact.rb` | Add `has_many :crm_activities` + `has_many :crm_tasks` + `has_many :crm_deals` | 3 lines |
| `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` | Import + spread CRM routes | 2 lines |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` | Add CRM menu entry after Companies | ~8 lines |
| `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactManageView.vue` | Add 2 tab options + 2 imports + 2 template conditionals | ~8 lines |
| `app/javascript/dashboard/i18n/locale/en/sidebar.json` (or equivalent) | Add CRM translation keys | 3 lines |

---

## Design Decisions & Rationale

1. **Namespace isolation over route partials**: The project doesn't use `draw()` route partials, so the CRM routes go directly in `routes.rb` but inside a `namespace :crm` block that's clearly delimited. This is still a single insertion point and easy to identify during merge conflicts.

2. **`self.table_name` in models**: Since models are in `app/models/crm/` directory but tables are prefixed `crm_*` (not `crm_*`), we explicitly set `self.table_name` to ensure Rails resolves the table correctly.

3. **Pinia over Vuex**: New stores use Pinia (`type: 'pinia'`) following the pattern established by the Companies feature — the most recent addition to Chatwoot.

4. **Application-level uniqueness for deals-per-pipeline**: PostgreSQL doesn't support cross-table unique constraints. We use a DB unique index on `(contact_id, stage_id)` as a partial safeguard plus a model-level custom validation that queries across stages within the same pipeline.

5. **Immutable activities via `readonly?`**: The `Crm::Activity` model returns `true` from `readonly?` when persisted, preventing accidental updates at the ORM level. The controller also doesn't expose update/destroy actions.

6. **Optimistic UI for drag-and-drop**: The Deals store applies the stage move locally before the API call and reverts on failure — this gives instant visual feedback on the Kanban board.

7. **Notification integration**: Rather than building a custom notification system, we leverage Chatwoot's existing `Notification` model with a new `notification_type` value. This gives us push notifications, email, and in-app notification for free.

8. **Separate cron jobs for overdue and reminders**: Different intervals (15min vs 5min) because reminders need more precision for user-facing notifications while overdue detection is a background status update.

---

## Correctness Properties

### Property 1: Multi-tenant isolation
Every query is scoped by `Current.account`. No CRM data from account A is ever visible to account B. All controllers inherit from `Api::V1::Accounts::BaseController` which sets `Current.account` from the URL parameter and verifies user membership.

**Validates: Requirements 10.1, 10.3, 10.4, 10.5**

### Property 2: One deal per contact per pipeline
Enforced by application-level validation in `Crm::Deal#one_deal_per_contact_per_pipeline` plus a DB unique index on `(contact_id, stage_id)`. The combination prevents both race conditions (DB level) and provides meaningful error messages (app level).

**Validates: Requirements 3.2, 13.6**

### Property 3: Activity immutability
The `Crm::Activity` model returns `true` from `readonly?` when persisted, preventing accidental updates at the ORM level. The controller only exposes `index` and `create` actions — no update or destroy endpoints exist.

**Validates: Requirements 4.4**

### Property 4: Task state machine
Only valid transitions are: `pending→completed`, `pending→overdue`, `overdue→completed`, `overdue→pending` (via due_date extension), `completed→pending` (reopen). Invalid transitions are rejected with appropriate error responses.

**Validates: Requirements 5.3, 6.1, 6.3, 6.4, 6.5, 7.2, 7.4, 7.5**

### Property 5: Reminder idempotency
The `reminded` boolean flag combined with the DB-level query condition (`WHERE reminded = false AND reminder_at <= NOW() AND status = 'pending'`) ensures a reminder is sent exactly once per setting. Updating `reminder_at` resets the flag to allow re-triggering.

**Validates: Requirements 8.5, 8.6**

### Property 6: Optimistic concurrency on Kanban
Frontend reverts card position on API failure, so the visual state never diverges from backend state for more than one HTTP round-trip.

**Validates: Requirements 2.4**

## Error Handling

| Scenario | Handling |
|----------|----------|
| Invalid params on create/update | 422 with field-level error messages from ActiveRecord validations |
| Resource not found in account scope | 404 (ActiveRecord::RecordNotFound rescued by BaseController) |
| Unauthorized action | 403 via Pundit::NotAuthorizedError (already handled globally) |
| Duplicate deal per pipeline | 422 custom validation error |
| Stage delete with existing deals | 422 with "Reassign deals before deleting" message |
| Pipeline delete with existing deals | 422 via `dependent: :restrict_with_error` |
| Task overdue job failure on single record | Logged, continues processing remaining records |
| Task reminder job failure on single record | Logged, continues processing remaining records |
| Drag-and-drop API failure | Frontend reverts card position, shows toast error |

## Testing Strategy

### Backend (RSpec)

- **Model specs** (`spec/models/crm/`): Validations, associations, scopes, custom methods (`complete!`, `reopen!`, `readonly?`)
- **Request specs** (`spec/requests/api/v1/accounts/crm/`): Full HTTP cycle testing for each controller action including success, 401, 403, 404, 422 cases
- **Job specs** (`spec/jobs/crm/`): Verify overdue detection correctly transitions status, reminder job creates notifications and sets `reminded = true`
- **Factories** (`spec/factories/`): One factory per model with valid defaults

### Frontend (Vitest)

- **Store specs**: Verify state mutations, API interactions (mocked), optimistic update + revert logic
- **Component specs**: Render verification, drag-and-drop event handling, form submission, tab switching
- **API client specs**: Verify correct URL construction and parameter passing
