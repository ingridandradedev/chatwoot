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
