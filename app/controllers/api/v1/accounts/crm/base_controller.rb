# app/controllers/api/v1/accounts/crm/base_controller.rb
module Api::V1::Accounts::Crm
  class BaseController < Api::V1::Accounts::BaseController
    before_action :check_authorization

    private

    def check_authorization(model = nil)
      model ||= "Crm::#{controller_name.classify}".constantize
      authorize(model)
    end

    def crm_pipelines
      Current.account.crm_pipelines
    end
  end
end
