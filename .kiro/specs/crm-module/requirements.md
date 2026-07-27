# Requirements Document

## Introduction

This document specifies the requirements for a lightweight CRM module integrated into a Chatwoot fork. The module adds pipeline management via a Kanban board, an immutable activity log for contacts, and a task management system with reminders. All functionality is scoped by account (multi-tenant) and built in isolated namespaces (`Crm::`) to minimize conflicts with upstream Chatwoot merges.

## Glossary

- **CRM_Module**: The lightweight customer relationship management module integrated into Chatwoot, encompassing pipelines, activities, and tasks.
- **Pipeline**: A configurable sales funnel belonging to an account, containing an ordered set of stages through which contacts progress (e.g., Novo → Qualificando → Proposta → Fechado Ganho → Fechado Perdido).
- **Stage**: A named column within a Pipeline representing a step in the sales process. Stages have a position attribute that defines their order in the Kanban board.
- **Deal**: A record linking a Contact to a specific Stage within a Pipeline, representing that contact's current position in the funnel. A contact can have at most one Deal per Pipeline.
- **Activity**: An immutable historical record of an event that occurred in relation to a contact (e.g., call made, email sent, meeting held, note added, stage changed, task completed). Activities have no deadline, no status, and cannot be edited or deleted after creation.
- **Task**: A future pending action item linked to a contact, with an assignee, deadline, status (pending, completed, overdue), and priority. Tasks represent work that still needs to be done.
- **Kanban_Board**: A visual board displaying Deals as cards organized into Stage columns, supporting drag-and-drop reordering.
- **Reminder**: An internal Chatwoot notification and/or email sent to the Task assignee before the Task deadline, processed via a Sidekiq background job.
- **Account**: The multi-tenant scope unit in Chatwoot. All CRM resources are scoped to an Account.
- **Agent**: A Chatwoot user with access to the dashboard, who can interact with CRM features according to their permissions.

## Requirements

### Requirement 1: Pipeline Management

**User Story:** As an agent, I want to manage multiple sales pipelines per account, so that I can track contacts through different sales processes simultaneously.

#### Acceptance Criteria

1. THE CRM_Module SHALL provide CRUD operations for Pipelines scoped to the current Account.
2. WHEN a Pipeline is created, THE CRM_Module SHALL require a name (between 1 and 255 characters, unique within the Account) and create a default set of stages (Novo, Qualificando, Proposta, Fechado Ganho, Fechado Perdido) with positions assigned sequentially starting at 1.
3. IF a Pipeline name is blank, exceeds 255 characters, or duplicates an existing Pipeline name within the same Account, THEN THE CRM_Module SHALL reject the request and return a validation error response indicating the reason for failure.
4. THE CRM_Module SHALL allow Agents to add, rename, reorder, and remove Stages within a Pipeline, where Stage names must be between 1 and 255 characters and a newly added Stage SHALL be assigned the next sequential position after the current last Stage.
5. WHEN a Stage is removed, THE CRM_Module SHALL require reassignment of all Deals in that Stage to another Stage within the same Pipeline before deletion proceeds.
6. THE CRM_Module SHALL enforce that each Pipeline has at least one Stage at all times.
7. IF an Agent attempts to delete a Pipeline that contains Deals in any of its Stages, THEN THE CRM_Module SHALL reject the deletion and return an error response indicating that all Deals must be removed or reassigned before the Pipeline can be deleted.
8. THE CRM_Module SHALL scope all Pipeline data by account_id, preventing cross-account data access.

### Requirement 2: Kanban Board Visualization

**User Story:** As an agent, I want to see contacts organized in a Kanban board by pipeline stages, so that I can quickly understand the status of leads and move them through the funnel.

#### Acceptance Criteria

1. THE CRM_Module SHALL display a Kanban board with columns representing the Stages of the selected Pipeline, ordered by Stage position, and SHALL provide a Pipeline selector that defaults to the most recently created Pipeline when multiple Pipelines exist for the Account.
2. THE Kanban_Board SHALL display Deal cards within each Stage column, showing at minimum the contact name and deal value, with a maximum of 20 Deal cards loaded per column initially and a mechanism to load additional cards on demand.
3. WHEN an Agent drags a Deal card from one Stage column to another, THE CRM_Module SHALL update the Deal's stage_id to the target Stage and visually move the card to the target column.
4. IF the stage update API call fails after a drag-and-drop operation, THEN THE CRM_Module SHALL revert the Deal card to its original Stage column and display an error message indicating the move could not be saved.
5. WHEN a Deal is moved between Stages via drag-and-drop, THE CRM_Module SHALL automatically create an Activity record of type "stage_change" on the associated Contact with the source stage, target stage, and Agent who performed the move.
6. THE CRM_Module SHALL be accessible from a new "CRM" item in the dashboard sidebar navigation menu.
7. WHEN no Pipeline exists for the Account, THE Kanban_Board SHALL display an empty state with a message indicating no pipelines exist and a button allowing the Agent to create a Pipeline.

### Requirement 3: Deal Management

**User Story:** As an agent, I want to create and manage deals linking contacts to pipeline stages, so that I can track each contact's progress through a sales funnel.

#### Acceptance Criteria

1. THE CRM_Module SHALL allow Agents to create a Deal by associating a Contact with a Stage within a Pipeline, requiring contact_id and stage_id, and optionally accepting a title (maximum 255 characters) and a monetary value (decimal, range 0.00 to 999,999,999.99).
2. IF an Agent attempts to create a Deal for a Contact that already has a Deal in the same Pipeline, THEN THE CRM_Module SHALL reject the request and return an error response indicating the duplicate constraint violation.
3. WHEN a Deal is created, THE CRM_Module SHALL record the contact_id, stage_id, account_id, and the creating Agent's user_id.
4. THE CRM_Module SHALL allow Agents to update a Deal's title, value, and stage assignment.
5. WHEN a Deal's stage assignment is updated, THE CRM_Module SHALL automatically create an Activity record of type "stage_change" on the associated Contact, recording the previous stage, the new stage, and the Agent who performed the update.
6. THE CRM_Module SHALL allow Agents to delete a Deal, removing it from the Kanban board.
7. IF an Agent attempts to create or update a Deal with a contact_id or stage_id that does not exist within the current Account, THEN THE CRM_Module SHALL reject the request and return an error response indicating the invalid reference.

### Requirement 4: Activity Log

**User Story:** As an agent, I want to view an immutable timeline of all activities related to a contact, so that I have a complete historical record of interactions.

#### Acceptance Criteria

1. THE CRM_Module SHALL store Activities in a dedicated `crm_activities` table, separate from Tasks.
2. THE CRM_Module SHALL support the following Activity types: call, email, meeting, note, stage_change, task_completed.
3. WHEN an Activity is created, THE CRM_Module SHALL record the activity_type, description, contact_id, account_id, user_id (author), and created_at timestamp.
4. IF a request attempts to update or delete an Activity via the API, THEN THE CRM_Module SHALL reject the request and return an error response indicating that Activities are immutable.
5. THE CRM_Module SHALL display Activities on the existing Contact detail page as a new "Activities" tab, ordered chronologically (most recent first) and paginated with a maximum of 20 activities per page.
6. THE CRM_Module SHALL allow Agents to manually create Activities of types: call, email, meeting, and note, with a required description field between 1 and 10,000 characters.
7. IF an Agent attempts to manually create an Activity of type stage_change or task_completed, THEN THE CRM_Module SHALL reject the request and return an error response indicating that these types are system-generated only.

### Requirement 5: Task Management

**User Story:** As an agent, I want to create tasks linked to contacts with deadlines, priority, and assignees, so that I can track pending work and ensure follow-ups happen on time.

#### Acceptance Criteria

1. THE CRM_Module SHALL store Tasks in a dedicated `crm_tasks` table, separate from Activities.
2. THE CRM_Module SHALL require the following fields for Task creation: title (maximum 255 characters, non-blank), contact_id, assignee_id (Agent), due_date, and priority (low, medium, high).
3. THE CRM_Module SHALL track Task status with the following values: pending, completed, overdue.
4. WHEN a Task is created, THE CRM_Module SHALL set the initial status to "pending" regardless of whether the due_date is in the past (the overdue detection cron job will update it on its next run).
5. WHILE a Task status is "pending" or "overdue", THE CRM_Module SHALL allow Agents to update the Task's title, description, assignee_id, due_date, and priority.
6. IF an Agent attempts to update a Task that has status "completed", THEN THE CRM_Module SHALL reject the update and return an error response indicating that completed tasks cannot be edited.
7. THE CRM_Module SHALL scope all Task data by account_id, preventing cross-account data access.
8. THE CRM_Module SHALL display Tasks associated with a Contact on the Contact detail page as a new "Tasks" tab, ordered by due_date ascending (earliest deadline first), with overdue tasks shown before pending tasks.
9. IF a Task creation request is missing any required field or contains an invalid contact_id or assignee_id, THEN THE CRM_Module SHALL reject the request and return an error response indicating which fields are invalid or missing.

### Requirement 6: Task Completion

**User Story:** As an agent, I want to mark tasks as completed and have that action automatically recorded in the contact's activity timeline, so that the historical record stays accurate without manual effort.

#### Acceptance Criteria

1. WHEN an Agent marks a Task that has status "pending" or "overdue" as completed, THE CRM_Module SHALL update the Task status to "completed" and record the completed_at timestamp and the completing Agent's user_id.
2. WHEN a Task is marked as completed, THE CRM_Module SHALL automatically create an Activity of type "task_completed" on the associated Contact, including the Task title in the Activity description.
3. IF an Agent attempts to mark a Task that already has status "completed" as completed again, THEN THE CRM_Module SHALL reject the request and return an error response indicating the Task is already completed.
4. WHEN an Agent reopens a completed Task, THE CRM_Module SHALL set the Task status back to "pending", clear the completed_at and completed_by fields, and leave any previously created "task_completed" Activity unchanged on the Contact timeline.
5. IF an Agent attempts to reopen a Task that does not have status "completed", THEN THE CRM_Module SHALL reject the request and return an error response indicating the Task is not in a completed state.

### Requirement 7: Task Overdue Detection

**User Story:** As an agent, I want tasks that pass their deadline to be automatically marked as overdue, so that I can quickly identify items that need immediate attention.

#### Acceptance Criteria

1. THE CRM_Module SHALL provide a Sidekiq cron job that runs at a configurable interval (default every 15 minutes) to identify Tasks with status "pending" and due_date earlier than the current server time.
2. WHEN the cron job identifies a pending Task with a due_date earlier than the current server time, THE CRM_Module SHALL update the Task status to "overdue".
3. WHEN a Task status changes to "overdue", THE CRM_Module SHALL not create an Activity record (overdue is an automated status, not a user action).
4. WHEN an Agent extends the due_date of an overdue Task to a future date, THE CRM_Module SHALL set the Task status back to "pending".
5. THE CRM_Module SHALL allow an overdue Task to be marked as completed following the same completion rules as a pending Task.
6. IF the cron job fails to update an individual Task, THEN THE CRM_Module SHALL log the error and continue processing the remaining Tasks in the batch without halting the job.
7. THE CRM_Module SHALL process only Tasks with status "pending" during the overdue detection scan, skipping Tasks with status "completed" or "overdue".

### Requirement 8: Task Reminders

**User Story:** As an agent, I want to receive reminders before a task is due, so that I can take action before the deadline passes.

#### Acceptance Criteria

1. THE CRM_Module SHALL allow Agents to set an optional reminder_at datetime when creating or updating a Task, provided that the reminder_at value is in the future and earlier than the Task's due_date.
2. WHEN the current time reaches a Task's reminder_at value and the Task status is "pending", THE CRM_Module SHALL create an internal Chatwoot notification for the Task assignee containing the Task title, associated Contact name, and due_date.
3. IF the Task assignee has email notifications enabled, THEN THE CRM_Module SHALL also send an email to the Task assignee via a Sidekiq job when the reminder is processed.
4. THE CRM_Module SHALL process reminders via a Sidekiq cron job (Crm::TaskReminderJob) that runs periodically (configurable interval, default every 5 minutes), selecting only Tasks where reminded is false, reminder_at is in the past or present, and status is "pending".
5. WHEN a reminder is successfully processed, THE CRM_Module SHALL set the Task's reminded field to true to prevent duplicate notifications.
6. WHEN an Agent updates a Task's reminder_at to a new value, THE CRM_Module SHALL reset the reminded field to false so that the new reminder will be sent at the updated time.
7. IF the reminder_at value is not earlier than due_date or is not in the future at the time of setting, THEN THE CRM_Module SHALL reject the input with a validation error indicating the constraint that was violated.

### Requirement 9: Namespace Isolation

**User Story:** As a developer, I want all CRM functionality to be isolated in dedicated namespaces, so that future merges with upstream Chatwoot are conflict-free.

#### Acceptance Criteria

1. THE CRM_Module SHALL place all backend models under the `Crm::` Ruby namespace in the `app/models/crm/` directory (e.g., `app/models/crm/pipeline.rb` defining `Crm::Pipeline`, `app/models/crm/stage.rb` defining `Crm::Stage`, `app/models/crm/deal.rb` defining `Crm::Deal`, `app/models/crm/activity.rb` defining `Crm::Activity`, `app/models/crm/task.rb` defining `Crm::Task`).
2. THE CRM_Module SHALL place all backend controllers under the `Api::V1::Accounts::Crm::` namespace in the `app/controllers/api/v1/accounts/crm/` directory (e.g., `app/controllers/api/v1/accounts/crm/pipelines_controller.rb`).
3. THE CRM_Module SHALL place all Pundit policies under the `Crm::` Ruby namespace in the `app/policies/crm/` subdirectory (e.g., `app/policies/crm/pipeline_policy.rb` defining `Crm::PipelinePolicy`).
4. THE CRM_Module SHALL place frontend code under `crm/` subdirectories within each existing dashboard category: `app/javascript/dashboard/routes/crm/`, `app/javascript/dashboard/stores/crm/`, `app/javascript/dashboard/api/crm/`, and `app/javascript/dashboard/components/crm/`.
5. THE CRM_Module SHALL prefix all database migration table names with `crm_` (e.g., `crm_pipelines`, `crm_stages`, `crm_deals`, `crm_activities`, `crm_tasks`).
6. THE CRM_Module SHALL register backend routes inside a `namespace :crm` block within the existing account-scoped routes, using a dedicated route file (e.g., `config/routes/crm.rb`) loaded via `draw(:crm)` to minimize merge conflicts on the main `config/routes.rb` file.
7. THE CRM_Module SHALL limit modifications to existing upstream files to no more than 5 lines of additive-only changes per file (e.g., adding a sidebar menu entry, loading a route file, or registering a tab), ensuring no existing lines are deleted or altered.
8. THE CRM_Module SHALL place all CRM-related Sidekiq job classes under the `Crm::` Ruby namespace in the `app/jobs/crm/` directory (e.g., `app/jobs/crm/overdue_task_job.rb`).

### Requirement 10: Multi-Tenant Data Isolation

**User Story:** As an administrator, I want all CRM data to be strictly scoped to my account, so that no data leaks between tenants.

#### Acceptance Criteria

1. THE CRM_Module SHALL include a non-nullable `account_id` foreign key on all CRM database tables (crm_pipelines, crm_stages, crm_deals, crm_activities, crm_tasks).
2. THE CRM_Module SHALL add database-level indexes on `account_id` for all CRM tables.
3. THE CRM_Module SHALL scope all controller queries by the current account (using the existing `current_account` pattern from `Api::V1::Accounts::BaseController`), including nested resource lookups where parent resources are resolved within the current account scope before loading child resources.
4. IF a request attempts to access a CRM resource belonging to a different account or a non-existent resource, THEN THE CRM_Module SHALL return a 404 Not Found response without revealing whether the resource exists in another account.
5. WHEN a CRM resource is created, THE CRM_Module SHALL assign the `account_id` from the server-side `current_account` context, ignoring any `account_id` value submitted in the request parameters.

### Requirement 11: Authorization

**User Story:** As an administrator, I want CRM access to be governed by Chatwoot's existing permission system, so that only authorized agents can manage CRM data.

#### Acceptance Criteria

1. THE CRM_Module SHALL create Pundit policies for Pipeline, Deal, Activity, and Task resources.
2. THE CRM_Module SHALL allow all authenticated Agents within an Account to read (index, show) CRM resources belonging to that Account.
3. THE CRM_Module SHALL allow all authenticated Agents within an Account to create and update Deals and Tasks, and to create Activities.
4. THE CRM_Module SHALL restrict Pipeline creation, update, and deletion to Agents with the "administrator" role.
5. THE CRM_Module SHALL restrict Deal deletion to Agents with the "administrator" role.
6. THE CRM_Module SHALL restrict Task deletion to the Task creator or Agents with the "administrator" role.
7. IF an Agent without the required role or ownership attempts a restricted action, THEN THE CRM_Module SHALL deny the request and return an authorization error response.
8. THE CRM_Module SHALL prevent Agents from accessing or modifying CRM resources belonging to a different Account than their own.

### Requirement 12: Frontend Integration

**User Story:** As an agent, I want the CRM module to feel like a native part of Chatwoot's dashboard, so that I can work with leads without switching contexts.

#### Acceptance Criteria

1. THE CRM_Module SHALL add a "CRM" item to the dashboard sidebar navigation array in `Sidebar.vue`, positioned immediately after the "Companies" item, with a distinct icon and child navigation items for the Kanban board view.
2. THE CRM_Module SHALL use the existing `vuedraggable` library (already in package.json) for drag-and-drop functionality on the Kanban board.
3. THE CRM_Module SHALL use Pinia stores for CRM state management, placed in the `app/javascript/dashboard/stores/` directory, exposing state, getters, and actions for leads, pipelines, activities, and tasks.
4. THE CRM_Module SHALL register frontend routes under the path `/app/accounts/:accountId/crm/` with at minimum a root route that renders the Kanban board view, and WHEN the user navigates to any registered CRM route, THE CRM_Module SHALL render the corresponding view within 1 second on a standard connection.
5. THE CRM_Module SHALL add "Activities" and "Tasks" tabs to the existing Contact detail page by appending them after the existing tabs in the `CONTACT_TABS_OPTIONS` array, without modifying the core `ContactManageView.vue` template structure — using a plugin registration pattern or an extension array that the Contact page imports from the CRM module.
6. WHEN the user navigates to the CRM sidebar item, THE CRM_Module SHALL highlight the "CRM" sidebar item as active and display the Kanban board as the default view.
7. IF the CRM frontend route path does not match any registered sub-route, THEN THE CRM_Module SHALL redirect the user to the CRM root Kanban board view rather than displaying a blank page.

### Requirement 13: Database Schema Design

**User Story:** As a developer, I want a well-structured database schema for the CRM module, so that data integrity is enforced at the database level.

#### Acceptance Criteria

1. THE CRM_Module SHALL create the `crm_pipelines` table with columns: id (bigint primary key), account_id (bigint, NOT NULL), name (string, max 255 characters, NOT NULL), created_at (datetime, NOT NULL), updated_at (datetime, NOT NULL).
2. THE CRM_Module SHALL create the `crm_stages` table with columns: id (bigint primary key), account_id (bigint, NOT NULL), pipeline_id (bigint, NOT NULL), name (string, max 255 characters, NOT NULL), position (integer, NOT NULL, default 0), created_at (datetime, NOT NULL), updated_at (datetime, NOT NULL).
3. THE CRM_Module SHALL create the `crm_deals` table with columns: id (bigint primary key), account_id (bigint, NOT NULL), contact_id (bigint, NOT NULL), stage_id (bigint, NOT NULL), title (string, max 255 characters, nullable), value (decimal(15,2), nullable), created_by_id (bigint, NOT NULL), created_at (datetime, NOT NULL), updated_at (datetime, NOT NULL).
4. THE CRM_Module SHALL create the `crm_activities` table with columns: id (bigint primary key), account_id (bigint, NOT NULL), contact_id (bigint, NOT NULL), user_id (bigint, NOT NULL), activity_type (integer, NOT NULL), description (text, NOT NULL), metadata (jsonb, default '{}'), created_at (datetime, NOT NULL).
5. THE CRM_Module SHALL create the `crm_tasks` table with columns: id (bigint primary key), account_id (bigint, NOT NULL), contact_id (bigint, NOT NULL), assignee_id (bigint, NOT NULL), created_by_id (bigint, NOT NULL), title (string, max 255 characters, NOT NULL), description (text, nullable), due_date (datetime, NOT NULL), reminder_at (datetime, nullable), reminded (boolean, NOT NULL, default false), priority (integer, NOT NULL, default 0), status (integer, NOT NULL, default 0), completed_at (datetime, nullable), completed_by_id (bigint, nullable), created_at (datetime, NOT NULL), updated_at (datetime, NOT NULL).
6. THE CRM_Module SHALL add a unique composite index on (contact_id, pipeline_id) on the `crm_deals` table — where pipeline_id is derived by joining through `crm_stages` — to enforce the one-Deal-per-Contact-per-Pipeline constraint. If the database does not support a direct cross-table unique index, the constraint SHALL be enforced via a unique index on (contact_id, stage_id) combined with an application-level validation that prevents a contact from having deals in multiple stages of the same pipeline.
7. THE CRM_Module SHALL add foreign key constraints on all CRM tables as follows: `crm_pipelines.account_id` references `accounts.id`; `crm_stages.account_id` references `accounts.id`; `crm_stages.pipeline_id` references `crm_pipelines.id`; `crm_deals.account_id` references `accounts.id`; `crm_deals.contact_id` references `contacts.id`; `crm_deals.stage_id` references `crm_stages.id`; `crm_deals.created_by_id` references `users.id`; `crm_activities.account_id` references `accounts.id`; `crm_activities.contact_id` references `contacts.id`; `crm_activities.user_id` references `users.id`; `crm_tasks.account_id` references `accounts.id`; `crm_tasks.contact_id` references `contacts.id`; `crm_tasks.assignee_id` references `users.id`; `crm_tasks.created_by_id` references `users.id`; `crm_tasks.completed_by_id` references `users.id` (nullable).
8. THE CRM_Module SHALL add database indexes on account_id, contact_id, and all foreign key columns on each CRM table to support query performance for multi-tenant scoped lookups.

### Requirement 14: API Design

**User Story:** As a developer, I want RESTful API endpoints for all CRM resources, so that the frontend and potential third-party integrations can interact with the CRM data.

#### Acceptance Criteria

1. THE CRM_Module SHALL expose the following RESTful endpoints under `/api/v1/accounts/:account_id/crm/`:
   - `pipelines` (index, show, create, update, destroy)
   - `pipelines/:pipeline_id/stages` (index, create, update, destroy, reorder)
   - `pipelines/:pipeline_id/deals` (index, show, create, update, destroy)
   - `contacts/:contact_id/activities` (index, create)
   - `contacts/:contact_id/tasks` (index, create)
   - `tasks` (index, show, update, destroy)
   - `tasks/:id/complete` (POST)
   - `tasks/:id/reopen` (POST)
2. WHEN a list endpoint is called, THE CRM_Module SHALL return paginated results with a default page size of 15 items, accepting an optional `page` query parameter, and including pagination metadata (current_page, per_page, total_entries) in the response body.
3. THE CRM_Module SHALL return JSON responses using JBuilder templates located in `app/views/api/v1/accounts/crm/`, following the same view structure and naming conventions used by existing Chatwoot API controllers.
4. IF a request references a CRM resource that does not exist within the current account, THEN THE CRM_Module SHALL return an empty response with HTTP status 404.
5. WHEN a list endpoint is called with filter parameters, THE CRM_Module SHALL support filtering deals by stage_id and status, filtering tasks by assignee_id and due_date range, and sorting by created_at or updated_at in ascending or descending order via `sort` and `direction` query parameters.
6. IF a create or update request contains invalid or missing required attributes, THEN THE CRM_Module SHALL return HTTP status 422 with a JSON response containing an error message indicating which validations failed.

### Requirement 15: Testing

**User Story:** As a developer, I want comprehensive test coverage for the CRM module, so that regressions are caught early and the module remains reliable.

#### Acceptance Criteria

1. THE CRM_Module SHALL include RSpec model specs for each CRM model (Pipeline, Stage, Deal, Activity, Task) with at least one spec example per defined validation rule, one per declared association, and one per named scope.
2. THE CRM_Module SHALL include RSpec request specs for each CRM API endpoint action (index, show, create, update, destroy where applicable) with at least one success-case example, one unauthenticated-access example returning HTTP 401, one unauthorized-role example returning HTTP 403, and one invalid-params example returning HTTP 422.
3. THE CRM_Module SHALL include Vitest specs for all frontend Pinia stores (pipeline store, deal store, activity store, task store) and API client modules, with at least one spec example per exported action or method verifying the expected return value or state mutation.
4. THE CRM_Module SHALL include Vitest component specs for the Kanban board and task management components, with at least one spec verifying initial rendering and one spec verifying user interaction triggers the expected event or state change per component.
5. THE CRM_Module SHALL follow existing factory patterns (FactoryBot) for test data generation, providing one factory file per CRM model located in `spec/factories/` with valid default attributes that produce persistable records without additional overrides.
6. THE CRM_Module SHALL have all RSpec and Vitest test suites pass with zero failures and zero pending examples before the module is considered complete.
