import PipelineAPI from 'dashboard/api/crm/pipelines';
import { createStore } from 'dashboard/store/storeFactory';

export const useCrmPipelinesStore = createStore({
  name: 'crmPipelines',
  type: 'pinia',
  API: PipelineAPI,
  state: () => ({
    currentPipelineId: null,
  }),
  getters: {
    getCurrentPipeline: state =>
      state.records.find(p => p.id === state.currentPipelineId) || null,
  },
  actions: () => ({
    setCurrentPipeline(pipelineId) {
      this.currentPipelineId = Number(pipelineId);
    },
  }),
});
