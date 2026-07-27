require 'rails_helper'

RSpec.describe 'CRM Tasks API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }

  describe 'GET /api/v1/accounts/:account_id/crm/contacts/:contact_id/tasks' do
    before { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

    context 'when authenticated as agent' do
      it 'returns tasks for the contact' do
        get "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/tasks",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/tasks"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/crm/tasks' do
    before { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

    context 'when authenticated as agent' do
      it 'returns all tasks for the account' do
        get "/api/v1/accounts/#{account.id}/crm/tasks",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/tasks"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/crm/tasks/:id' do
    let(:task) { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

    context 'when authenticated as agent' do
      it 'returns the task' do
        get "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/contacts/:contact_id/tasks' do
    let(:valid_params) do
      { task: { title: 'Follow up', assignee_id: agent.id, due_date: 3.days.from_now.iso8601, priority: 'medium' } }
    end

    context 'when authenticated as agent' do
      it 'creates a task' do
        expect do
          post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/tasks",
               params: valid_params,
               headers: agent.create_new_auth_token,
               as: :json
        end.to change(Crm::Task, :count).by(1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/tasks",
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when params are invalid' do
      it 'returns unprocessable_entity for blank title' do
        post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/tasks",
             params: { task: { title: '', assignee_id: agent.id, due_date: 3.days.from_now.iso8601 } },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/tasks/:id' do
    let(:task) { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

    context 'when authenticated as agent' do
      it 'updates the task' do
        patch "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
              params: { task: { title: 'Updated Title' } },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(task.reload.title).to eq('Updated Title')
      end

      it 'returns unprocessable_entity when task is completed' do
        completed_task = create(:crm_task, :completed, account: account, contact: contact, assignee: agent, created_by: agent)

        patch "/api/v1/accounts/#{account.id}/crm/tasks/#{completed_task.id}",
              params: { task: { title: 'Try edit' } },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Cannot edit completed task')
      end

      it 'resets overdue task to pending when due_date is extended' do
        overdue_task = create(:crm_task, :overdue, account: account, contact: contact, assignee: agent, created_by: agent)

        patch "/api/v1/accounts/#{account.id}/crm/tasks/#{overdue_task.id}",
              params: { task: { due_date: 5.days.from_now.iso8601 } },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(overdue_task.reload.status).to eq('pending')
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
              params: { task: { title: 'New Title' } },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/crm/tasks/:id' do
    context 'when authenticated as the task creator' do
      let!(:task) { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

      it 'destroys the task' do
        expect do
          delete "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
                 headers: agent.create_new_auth_token
        end.to change(Crm::Task, :count).by(-1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as admin (not creator)' do
      let!(:task) { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

      it 'destroys the task (admin can delete any task)' do
        expect do
          delete "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
                 headers: admin.create_new_auth_token
        end.to change(Crm::Task, :count).by(-1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as agent who is not the creator' do
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let!(:task) { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}",
               headers: other_agent.create_new_auth_token

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when unauthenticated' do
      let!(:task) { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/tasks/:id/complete' do
    let(:task) { create(:crm_task, account: account, contact: contact, assignee: agent, created_by: agent) }

    context 'when authenticated as agent' do
      it 'completes the task and creates a completion activity' do
        expect do
          post "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}/complete",
               headers: agent.create_new_auth_token
        end.to change(Crm::Activity, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(task.reload.status).to eq('completed')
        expect(task.completed_by).to eq(agent)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}/complete"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/tasks/:id/reopen' do
    let(:task) { create(:crm_task, :completed, account: account, contact: contact, assignee: agent, created_by: agent) }

    context 'when authenticated as agent' do
      it 'reopens the task' do
        post "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}/reopen",
             headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(task.reload.status).to eq('pending')
        expect(task.completed_at).to be_nil
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/tasks/#{task.id}/reopen"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
