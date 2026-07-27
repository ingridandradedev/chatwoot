require 'rails_helper'

RSpec.describe 'CRM Activities API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }

  describe 'GET /api/v1/accounts/:account_id/crm/contacts/:contact_id/activities' do
    before { create(:crm_activity, account: account, contact: contact, user: agent) }

    context 'when authenticated as agent' do
      it 'returns activities for the contact' do
        get "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/activities",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:success)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/activities"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/contacts/:contact_id/activities' do
    let(:valid_params) { { activity: { activity_type: 'note', description: 'Called the client' } } }

    context 'when authenticated as agent' do
      it 'creates a manual activity' do
        expect do
          post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/activities",
               params: valid_params,
               headers: agent.create_new_auth_token,
               as: :json
        end.to change(Crm::Activity, :count).by(1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when trying to create a system-type activity' do
      it 'returns unprocessable_entity for stage_change type' do
        post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/activities",
             params: { activity: { activity_type: 'stage_change', description: 'Trying system type' } },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Only manual types allowed')
      end

      it 'returns unprocessable_entity for task_completed type' do
        post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/activities",
             params: { activity: { activity_type: 'task_completed', description: 'Trying system type' } },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Only manual types allowed')
      end
    end

    context 'when params are invalid' do
      it 'returns unprocessable_entity for blank description' do
        post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/activities",
             params: { activity: { activity_type: 'note', description: '' } },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/crm/contacts/#{contact.id}/activities",
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
