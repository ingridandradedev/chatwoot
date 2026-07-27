/* global axios */
import ApiClient from '../ApiClient';

class PipelineAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
  }
}

export default new PipelineAPI();
