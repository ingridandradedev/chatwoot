import { defineStore } from 'pinia';
import ActivityAPI from 'dashboard/api/crm/activities';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useCrmActivitiesStore = defineStore('crmActivities', {
  state: () => ({
    activities: [],
    meta: {
      totalCount: 0,
      page: 1,
      totalPages: 1,
    },
    uiFlags: {
      fetchingList: false,
      creatingItem: false,
    },
  }),

  getters: {
    getActivities: state => state.activities,
    getMeta: state => state.meta,
    getUIFlags: state => state.uiFlags,
  },

  actions: {
    setUIFlag(data) {
      this.uiFlags = { ...this.uiFlags, ...data };
    },

    setMeta(meta) {
      this.meta = {
        totalCount: Number(meta.total_count || meta.totalCount || 0),
        page: Number(meta.page || meta.current_page || 1),
        totalPages: Number(meta.total_pages || meta.totalPages || 1),
      };
    },

    async fetchForContact(contactId, page = 1) {
      this.setUIFlag({ fetchingList: true });
      try {
        const { data } = await ActivityAPI.getForContact(contactId, { page });
        const payload = data.payload || data;
        if (page === 1) {
          this.activities = Array.isArray(payload) ? payload : [];
        } else {
          this.activities = [
            ...this.activities,
            ...(Array.isArray(payload) ? payload : []),
          ];
        }
        if (data.meta) {
          this.setMeta(data.meta);
        }
        return this.activities;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    async createForContact(contactId, data) {
      this.setUIFlag({ creatingItem: true });
      try {
        const { data: responseData } = await ActivityAPI.createForContact(
          contactId,
          data
        );
        const activity = responseData.payload || responseData;
        this.activities.unshift(activity);
        return activity;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ creatingItem: false });
      }
    },

    reset() {
      this.activities = [];
      this.meta = { totalCount: 0, page: 1, totalPages: 1 };
    },
  },
});
