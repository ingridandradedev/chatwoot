/* global axios */
import ApiClient from '../ApiClient';

class StageAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
  }

  getStages(pipelineId) {
    return axios.get(`${this.url}/${pipelineId}/stages`);
  }

  createStage(pipelineId, data) {
    return axios.post(`${this.url}/${pipelineId}/stages`, data);
  }

  updateStage(pipelineId, stageId, data) {
    return axios.patch(`${this.url}/${pipelineId}/stages/${stageId}`, data);
  }

  deleteStage(pipelineId, stageId) {
    return axios.delete(`${this.url}/${pipelineId}/stages/${stageId}`);
  }

  reorderStages(pipelineId, positions) {
    return axios.post(`${this.url}/${pipelineId}/stages/reorder`, {
      positions,
    });
  }
}

export default new StageAPI();
