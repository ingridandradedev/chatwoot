/* global axios */
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

  create(pipelineId, data) {
    return axios.post(`${this.url}/${pipelineId}/deals`, { deal: data });
  }

  update(pipelineId, dealId, data) {
    return axios.patch(`${this.url}/${pipelineId}/deals/${dealId}`, {
      deal: data,
    });
  }

  delete(pipelineId, dealId) {
    return axios.delete(`${this.url}/${pipelineId}/deals/${dealId}`);
  }
}

export default new DealAPI();
