import { defineStore } from 'pinia';
import DealAPI from 'dashboard/api/crm/deals';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useCrmDealsStore = defineStore('crmDeals', {
  state: () => ({
    dealsByStage: {},
    uiFlags: {
      fetchingList: false,
      creatingItem: false,
      updatingItem: false,
      deletingItem: false,
    },
  }),

  getters: {
    getDealsForStage: state => stageId => state.dealsByStage[stageId] || [],
    getUIFlags: state => state.uiFlags,
  },

  actions: {
    setUIFlag(data) {
      this.uiFlags = { ...this.uiFlags, ...data };
    },

    async fetchForPipeline(pipelineId) {
      this.setUIFlag({ fetchingList: true });
      try {
        const {
          data: { payload },
        } = await DealAPI.getForPipeline(pipelineId);
        this.dealsByStage = payload.reduce((acc, deal) => {
          (acc[deal.stage_id] ||= []).push(deal);
          return acc;
        }, {});
        return payload;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    async moveToStage(pipelineId, dealId, fromStageId, toStageId) {
      // Optimistic update
      const deal = this.dealsByStage[fromStageId]?.find(
        d => d.id === dealId
      );
      if (!deal) return;

      this.dealsByStage[fromStageId] = this.dealsByStage[fromStageId].filter(
        d => d.id !== dealId
      );
      (this.dealsByStage[toStageId] ||= []).push({
        ...deal,
        stage_id: toStageId,
      });

      try {
        await DealAPI.moveToStage(pipelineId, dealId, toStageId);
      } catch (error) {
        // Revert on failure
        this.dealsByStage[toStageId] = this.dealsByStage[toStageId].filter(
          d => d.id !== dealId
        );
        (this.dealsByStage[fromStageId] ||= []).push(deal);
        throwErrorMessage(error);
      }
    },

    async createDeal(pipelineId, data) {
      this.setUIFlag({ creatingItem: true });
      try {
        const { data: responseData } = await DealAPI.create(pipelineId, data);
        const deal = responseData.payload || responseData;
        (this.dealsByStage[deal.stage_id] ||= []).push(deal);
        return deal;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ creatingItem: false });
      }
    },

    async updateDeal(pipelineId, dealId, data) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data: responseData } = await DealAPI.update(
          pipelineId,
          dealId,
          data
        );
        const updatedDeal = responseData.payload || responseData;
        // Update in the correct stage bucket
        Object.keys(this.dealsByStage).forEach(stageId => {
          const index = this.dealsByStage[stageId].findIndex(
            d => d.id === dealId
          );
          if (index !== -1) {
            this.dealsByStage[stageId].splice(index, 1);
          }
        });
        (this.dealsByStage[updatedDeal.stage_id] ||= []).push(updatedDeal);
        return updatedDeal;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async deleteDeal(pipelineId, dealId) {
      this.setUIFlag({ deletingItem: true });
      try {
        await DealAPI.delete(pipelineId, dealId);
        Object.keys(this.dealsByStage).forEach(stageId => {
          this.dealsByStage[stageId] = this.dealsByStage[stageId].filter(
            d => d.id !== dealId
          );
        });
        return dealId;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ deletingItem: false });
      }
    },
  },
});
