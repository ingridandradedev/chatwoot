# Implementation Plan: CRM Module

## Overview

This plan implements a lightweight CRM module for a Chatwoot fork, delivering pipeline/Kanban management, an immutable activity log, and task management with reminders. The implementation is organized into backend (Rails) and frontend (Vue 3) phases, building incrementally from database schema through models, controllers, and finally the UI layer. All code is isolated in `Crm::` namespaces.

## Tasks

- [x] 1. Database migrations and schema setup
  - [x] 1.1 Create migration for crm_pipelines and crm_stages tables
    - Create `db/migrate/YYYYMMDDHHMMSS_create_crm_pipelines_and_stages.rb`
    - Define crm_pipelines table with account_id, name, timestamps
    - Define crm_stages table with account_id, pipeline_id, name, position, timestamps
    - Add unique index on (account_id, name) for pipelines
    - Add index on (pipeline_id, position) for stages
    - Add foreign key constraints
    - _Requirements: 13.1, 13.2, 13.7, 13.8_

  - [x] 1.2 Create migration for crm_deals table
    - Create `db/migrate/YYYYMMDDHHMMSS_create_crm_deals.rb`
    - Define crm_deals table with account_id, contact_id, stage_id, title, value, created_by_id, timestamps
    - Add unique index on (contact_id, stage_id)
    - Add foreign key constraints to accounts, contacts, crm_stages, users
    - _Requirements: 13.3, 13.6, 13.7, 13.8_

  - [x] 1.3 Create migration for crm_activities table
    - Create `db/migrate/YYYYMMDDHHMMSS_create_crm_activities.rb`
    - Define crm_activities table with account_id, contact_id, user_id, activity_type, description, metadata, created_at (no updated_at)
    - Add indexes on (contact_id, created_at) and account_id
    - Add foreign key constraints
    - _Requirements: 13.4, 13.7, 13.8_

  - [x] 1.4 Create migration for crm_tasks table
    - Create `db/migrate/YYYYMMDDHHMMSS_create_crm_tasks.rb`
    - Define crm_tasks table with all columns per design (assignee_id, created_by_id, title, description, due_date, reminder_at, reminded, priority, status, completed_at, completed_by_id)
    - Add indexes on assignee_id, (status, due_date), (reminded, reminder_at, status), account_id
    - Add foreign key constraints to users for assignee_id, created_by_id, completed_by_id
    - _Requirements: 13.5, 13.7, 13.8_

- [x] 2. Backend models
  - [x] 2.1 Create Crm::Pipeline model
    - Create `app/models/crm/pipeline.rb` with validations, associations, and `create_default_stages` callback
    - Set `self.table_name = 'crm_pipelines'`
    - Add `belongs_to :account`, `has_many :stages`, `has_many :deals through: :stages`
    - Validate name presence, length, uniqueness scoped to account_id
    - Implement `after_create :create_default_stages` with default stages (Novo, Qualificando, Proposta, Fechado Ganho, Fechado Perdido)
    - _Requirements: 1.1, 1.2, 1.3, 9.1_

  - [x] 2.2 Create Crm::Stage model
    - Create `app/models/crm/stage.rb` with validations and associations
    - Set `self.table_name = 'crm_stages'`
    - Add `belongs_to :account`, `belongs_to :pipeline`, `has_many :deals`
    - Validate name presence/length, position presence/numericality
    - Add `scope :ordered` for position ordering
    - Use `dependent: :restrict_with_error` on deals association
    - _Requirements: 1.4, 1.5, 1.6, 9.1_

  - [x] 2.3 Create Crm::Deal model
    - Create `app/models/crm/deal.rb` with validations and custom uniqueness check
    - Set `self.table_name = 'crm_deals'`
    - Add associations: account, contact, stage, created_by (User)
    - Implement `one_deal_per_contact_per_pipeline` custom validation
    - Validate value numericality range (0 to 999,999,999.99)
    - _Requirements: 3.1, 3.2, 3.3, 9.1_

  - [x] 2.4 Create Crm::Activity model
    - Create `app/models/crm/activity.rb` with enum, immutability, and validations
    - Set `self.table_name = 'crm_activities'`
    - Define `activity_type` enum (call, email, meeting, note, stage_change, task_completed)
    - Define MANUAL_TYPES and SYSTEM_TYPES constants
    - Implement `readonly?` method returning true when persisted
    - Add `scope :recent_first`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 9.1_

  - [x] 2.5 Create Crm::Task model
    - Create `app/models/crm/task.rb` with enums, validations, and state methods
    - Set `self.table_name = 'crm_tasks'`
    - Define `priority` enum (low, medium, high) and `status` enum (pending, completed, overdue)
    - Implement `complete!` method with transaction (status update + activity creation)
    - Implement `reopen!` method with guard clause
    - Add `reminder_before_due_date` validation
    - Add scopes: `pending_and_overdue`, `due_before`, `needs_reminder`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 6.1, 6.2, 6.4, 8.1, 9.1_

  - [x] 2.6 Add CRM associations to existing Account and Contact models
    - Add `has_many :crm_pipelines, class_name: 'Crm::Pipeline'` to `app/models/account.rb`
    - Add `has_many :crm_activities`, `has_many :crm_tasks`, `has_many :crm_deals` to `app/models/contact.rb`
    - _Requirements: 9.7, 10.1_

- [x] 3. Pundit policies
  - [x] 3.1 Create CRM authorization policies
    - Create `app/policies/crm/pipeline_policy.rb` — admin-only for CUD, all agents for read
    - Create `app/policies/crm/stage_policy.rb` — admin-only for CUD, all agents for read
    - Create `app/policies/crm/deal_policy.rb` — all agents CRU, admin-only delete
    - Create `app/policies/crm/activity_policy.rb` — all agents index + create only
    - Create `app/policies/crm/task_policy.rb` — all agents CRUD, delete restricted to creator or admin
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7_

- [x] 4. API controllers and routes
  - [x] 4.1 Create CRM base controller
    - Create `app/controllers/api/v1/accounts/crm/base_controller.rb`
    - Inherit from `Api::V1::Accounts::BaseController`
    - Add `before_action :check_authorization`
    - Provide `crm_pipelines` helper method scoped to Current.account
    - _Requirements: 10.3, 14.1_

  - [x] 4.2 Create Pipelines controller
    - Create `app/controllers/api/v1/accounts/crm/pipelines_controller.rb`
    - Implement index, show, create, update, destroy actions
    - Use `policy_scope` for index
    - Apply pipeline_params permit for :name
    - _Requirements: 1.1, 1.7, 14.1, 14.2_

  - [x] 4.3 Create Stages controller
    - Create `app/controllers/api/v1/accounts/crm/stages_controller.rb`
    - Implement index, create, update, destroy, reorder actions
    - Check for existing deals before destroy (return 422 with message)
    - Implement reorder action with position updates
    - _Requirements: 1.4, 1.5, 14.1_

  - [x] 4.4 Create Deals controller
    - Create `app/controllers/api/v1/accounts/crm/deals_controller.rb`
    - Implement index (with stage_id filter, pagination), show, create, update, destroy
    - Implement `create_stage_change_activity` when stage changes on update
    - _Requirements: 3.1, 3.3, 3.4, 3.5, 3.6, 14.1, 14.2, 14.5_

  - [x] 4.5 Create Activities controller
    - Create `app/controllers/api/v1/accounts/crm/activities_controller.rb`
    - Implement index (paginated, recent_first) and create (manual types only)
    - Reject system-generated types with 422 error
    - _Requirements: 4.5, 4.6, 4.7, 14.1, 14.2_

  - [x] 4.6 Create Tasks controller
    - Create `app/controllers/api/v1/accounts/crm/tasks_controller.rb`
    - Implement index (global + per-contact), show, create, update, destroy, complete, reopen actions
    - Block updates on completed tasks (422)
    - Reset status to pending if overdue task gets future due_date
    - Reset reminded flag if reminder_at changes
    - _Requirements: 5.5, 5.6, 5.7, 5.8, 6.1, 6.3, 6.4, 6.5, 7.4, 8.6, 14.1, 14.2_

  - [x] 4.7 Register CRM routes in config/routes.rb
    - Add `namespace :crm` block inside account-scoped routes
    - Define all RESTful resource routes for pipelines, stages, deals, activities, tasks
    - Add member routes for complete/reopen on tasks
    - Add collection route for stage reorder
    - _Requirements: 9.6, 14.1_

- [x] 5. JBuilder views
  - [x] 5.1 Create JBuilder views for all CRM resources
    - Create `app/views/api/v1/accounts/crm/pipelines/` — index, show, _pipeline partial
    - Create `app/views/api/v1/accounts/crm/stages/` — index, _stage partial
    - Create `app/views/api/v1/accounts/crm/deals/` — index, show, _deal partial (with contact info)
    - Create `app/views/api/v1/accounts/crm/activities/` — index, create, _activity partial
    - Create `app/views/api/v1/accounts/crm/tasks/` — index, show, create, _task partial
    - Include pagination metadata (count, current_page) in index views
    - _Requirements: 14.2, 14.3_

- [x] 6. Background jobs
  - [x] 6.1 Create Crm::TaskOverdueJob
    - Create `app/jobs/crm/task_overdue_job.rb`
    - Query pending tasks with due_date before current time
    - Update status to :overdue with error handling per record
    - Log errors and continue processing on individual failures
    - _Requirements: 7.1, 7.2, 7.6, 7.7_

  - [x] 6.2 Create Crm::TaskReminderJob
    - Create `app/jobs/crm/task_reminder_job.rb`
    - Query tasks where reminded=false, reminder_at <= now, status=pending
    - Create Chatwoot Notification with task details
    - Set reminded=true after successful notification
    - Handle errors per record without halting
    - _Requirements: 8.2, 8.3, 8.4, 8.5_

  - [x] 6.3 Add notification_type and schedule config
    - Add `crm_task_reminder: 9` to `Notification::NOTIFICATION_TYPES` in `app/models/notification.rb`
    - Add cron entries to `config/schedule.yml` for both jobs (15min / 5min intervals)
    - _Requirements: 7.1, 8.4_

- [x] 7. Checkpoint - Backend complete
  - Ensure all migrations run successfully, models load without errors, and routes are recognized.
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Backend test coverage
  - [x] 8.1 Create FactoryBot factories for CRM models
    - Create `spec/factories/crm_pipelines.rb`
    - Create `spec/factories/crm_stages.rb`
    - Create `spec/factories/crm_deals.rb`
    - Create `spec/factories/crm_activities.rb`
    - Create `spec/factories/crm_tasks.rb`
    - Each factory must produce persistable records with valid defaults
    - _Requirements: 15.5_

  - [x] 8.2 Write RSpec model specs for CRM models
    - Create `spec/models/crm/pipeline_spec.rb` — validations, associations, default stages callback
    - Create `spec/models/crm/stage_spec.rb` — validations, associations, ordered scope
    - Create `spec/models/crm/deal_spec.rb` — validations, associations, one-deal-per-pipeline validation
    - Create `spec/models/crm/activity_spec.rb` — validations, enum, readonly?, recent_first scope
    - Create `spec/models/crm/task_spec.rb` — validations, enums, complete!, reopen!, scopes, reminder validation
    - _Requirements: 15.1_

  - [x] 8.3 Write RSpec request specs for CRM controllers
    - Create `spec/requests/api/v1/accounts/crm/pipelines_spec.rb` — CRUD + auth cases
    - Create `spec/requests/api/v1/accounts/crm/stages_spec.rb` — CRUD + reorder + deal reassignment check
    - Create `spec/requests/api/v1/accounts/crm/deals_spec.rb` — CRUD + stage_change activity + duplicate check
    - Create `spec/requests/api/v1/accounts/crm/activities_spec.rb` — index + create + system type rejection
    - Create `spec/requests/api/v1/accounts/crm/tasks_spec.rb` — CRUD + complete + reopen + overdue extension
    - Each spec includes success, 401, 403, and 422 cases
    - _Requirements: 15.2_

  - [x] 8.4 Write RSpec job specs for background jobs
    - Create `spec/jobs/crm/task_overdue_job_spec.rb` — status transition, skip completed/overdue, error handling
    - Create `spec/jobs/crm/task_reminder_job_spec.rb` — notification creation, reminded flag, error handling
    - _Requirements: 15.1, 15.2_

- [x] 9. Frontend API clients
  - [x] 9.1 Create CRM API client modules
    - Create `app/javascript/dashboard/api/crm/pipelines.js` — PipelineAPI extending ApiClient
    - Create `app/javascript/dashboard/api/crm/deals.js` — DealAPI with getForPipeline, moveToStage methods
    - Create `app/javascript/dashboard/api/crm/activities.js` — ActivityAPI with getForContact, createForContact
    - Create `app/javascript/dashboard/api/crm/tasks.js` — TaskAPI with getForContact, createForContact, complete, reopen
    - _Requirements: 12.3, 14.1_

- [x] 10. Frontend Pinia stores
  - [x] 10.1 Create CRM Pinia stores
    - Create `app/javascript/dashboard/stores/crm/pipelines.js` using store factory
    - Create `app/javascript/dashboard/stores/crm/deals.js` with dealsByStage state, optimistic moveToStage action, revert logic
    - Create `app/javascript/dashboard/stores/crm/activities.js` with pagination support
    - Create `app/javascript/dashboard/stores/crm/tasks.js` with filtering by assignee/status
    - _Requirements: 12.3_

- [x] 11. Frontend routes and navigation
  - [x] 11.1 Create CRM route definitions and register in dashboard router
    - Create `app/javascript/dashboard/routes/dashboard/crm/routes.js` with routes for CrmIndex, PipelineSettings
    - Import and spread CRM routes in `dashboard.routes.js`
    - _Requirements: 12.4, 12.7_

  - [x] 11.2 Add CRM sidebar navigation entry
    - Add CRM menu item to `Sidebar.vue` after Companies entry with icon, label, and child routes
    - Add i18n translation keys for CRM sidebar labels
    - _Requirements: 2.6, 12.1, 12.6_

- [x] 12. Kanban board components
  - [x] 12.1 Create KanbanBoard.vue page component
    - Create `app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndex.vue`
    - Implement pipeline selector dropdown (defaults to most recently created)
    - Fetch pipelines on mount, fetch deals when pipeline selection changes
    - Display empty state when no pipelines exist with create button
    - _Requirements: 2.1, 2.7_

  - [x] 12.2 Create KanbanColumn.vue and DealCard.vue components
    - Create `app/javascript/dashboard/components/crm/KanbanColumn.vue` with vuedraggable integration
    - Create `app/javascript/dashboard/components/crm/DealCard.vue` showing contact name and deal value
    - Emit deal-moved event on drag end with dealId, fromStageId, toStageId
    - _Requirements: 2.2, 2.3, 2.4, 12.2_

  - [x] 12.3 Create DealFormModal.vue for deal creation/editing
    - Create `app/javascript/dashboard/components/crm/DealFormModal.vue`
    - Form with contact selector, stage selector, title, value fields
    - Validate required fields before submission
    - _Requirements: 3.1, 3.4_

- [x] 13. Activity and Task UI components
  - [x] 13.1 Create ActivityTimeline.vue and ActivityForm.vue
    - Create `app/javascript/dashboard/components/crm/ActivityTimeline.vue` — chronological list with pagination
    - Create `app/javascript/dashboard/components/crm/ActivityForm.vue` — form with type selector (manual types only) and description textarea
    - _Requirements: 4.5, 4.6_

  - [x] 13.2 Create TaskList.vue, TaskCard.vue, and TaskFormModal.vue
    - Create `app/javascript/dashboard/components/crm/TaskList.vue` — ordered by due_date, overdue first
    - Create `app/javascript/dashboard/components/crm/TaskCard.vue` — shows title, assignee, due_date, priority badge, complete/reopen actions
    - Create `app/javascript/dashboard/components/crm/TaskFormModal.vue` — form with title, description, assignee, due_date, reminder_at, priority
    - _Requirements: 5.2, 5.8, 6.1, 6.4, 8.1_

  - [x] 13.3 Create PipelineSettings.vue page
    - Create `app/javascript/dashboard/routes/dashboard/crm/pages/PipelineSettings.vue`
    - Implement pipeline CRUD interface (admin only)
    - Stage management: add, rename, reorder (drag), delete with deal reassignment prompt
    - _Requirements: 1.1, 1.4, 1.5, 1.6_

- [x] 14. Contact detail page integration
  - [x] 14.1 Add CRM tabs to Contact detail page
    - Create `app/javascript/dashboard/components-next/Contacts/ContactsSidebar/ContactCrmActivities.vue`
    - Create `app/javascript/dashboard/components-next/Contacts/ContactsSidebar/ContactCrmTasks.vue`
    - Add 'CRM_ACTIVITIES' and 'CRM_TASKS' to CONTACT_TABS_OPTIONS array in ContactManageView.vue
    - Add template conditionals for new tab components
    - _Requirements: 4.5, 5.8, 12.5_

- [x] 15. Checkpoint - Frontend complete
  - Ensure frontend compiles without errors, routes resolve, and Kanban board renders.
  - Ensure all tests pass, ask the user if questions arise.

- [x] 16. Frontend test coverage
  - [x] 16.1 Write Vitest specs for CRM Pinia stores
    - Test pipeline store fetch and state population
    - Test deal store optimistic move + revert on failure
    - Test activity store pagination
    - Test task store filtering and complete/reopen actions
    - _Requirements: 15.3_

  - [x] 16.2 Write Vitest specs for CRM API clients
    - Test correct URL construction for each API method
    - Test parameter passing for filters and pagination
    - _Requirements: 15.3_

  - [x] 16.3 Write Vitest component specs for Kanban board and tasks
    - Test KanbanBoard initial render with pipeline selector and columns
    - Test drag-and-drop triggers deal-moved event
    - Test TaskCard complete/reopen interaction
    - Test DealFormModal form submission
    - _Requirements: 15.4_

- [x] 17. Final checkpoint - All tests pass
  - Run full RSpec suite and verify zero failures
  - Run full Vitest suite and verify zero failures
  - Verify all CRM routes respond correctly
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at backend and frontend boundaries
- The design uses Ruby (Rails 7.1) for backend and JavaScript (Vue 3 + Pinia) for frontend — no pseudocode translation needed
- All CRM code is namespaced under `Crm::` (backend) and `/crm/` directories (frontend) per Requirement 9
- Existing upstream files receive minimal additive-only changes (≤5 lines per file) per Requirement 9.7
- The `vuedraggable` library is already available in the project's package.json

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4", "2.5", "2.6"] },
    { "id": 2, "tasks": ["3.1", "4.1"] },
    { "id": 3, "tasks": ["4.2", "4.3", "4.4", "4.5", "4.6", "4.7"] },
    { "id": 4, "tasks": ["5.1", "6.1", "6.2", "6.3"] },
    { "id": 5, "tasks": ["8.1"] },
    { "id": 6, "tasks": ["8.2", "8.3", "8.4"] },
    { "id": 7, "tasks": ["9.1"] },
    { "id": 8, "tasks": ["10.1"] },
    { "id": 9, "tasks": ["11.1", "11.2"] },
    { "id": 10, "tasks": ["12.1", "12.2", "12.3"] },
    { "id": 11, "tasks": ["13.1", "13.2", "13.3"] },
    { "id": 12, "tasks": ["14.1"] },
    { "id": 13, "tasks": ["16.1", "16.2", "16.3"] }
  ]
}
```
