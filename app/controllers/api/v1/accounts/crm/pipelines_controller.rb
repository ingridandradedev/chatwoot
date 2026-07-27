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
