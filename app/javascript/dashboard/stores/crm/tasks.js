import { defineStore } from 'pinia';
import TaskAPI from 'dashboard/api/crm/tasks';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useCrmTasksStore = defineStore('crmTasks', {
  state: () => ({
    tasks: [],
    meta: {
      totalCount: 0,
      page: 1,
      totalPages: 1,
    },
    filters: {
      assigneeId: null,
      status: null,
    },
    uiFlags: {
      fetchingList: false,
      creatingItem: false,
      updatingItem: false,
      deletingItem: false,
    },
  }),

  getters: {
    getTasks: state => state.tasks,
    getMeta: state => state.meta,
    getUIFlags: state => state.uiFlags,
    getFilters: state => state.filters,
    getFilteredTasks: state => {
      let filtered = state.tasks;
      if (state.filters.assigneeId) {
        filtered = filtered.filter(
          t => t.assignee_id === state.filters.assigneeId
        );
      }
      if (state.filters.status) {
        filtered = filtered.filter(t => t.status === state.filters.status);
      }
      return filtered;
    },
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

    setFilters({ assigneeId, status } = {}) {
      if (assigneeId !== undefined) this.filters.assigneeId = assigneeId;
      if (status !== undefined) this.filters.status = status;
    },

    clearFilters() {
      this.filters = { assigneeId: null, status: null };
    },

    async fetchAll(params = {}) {
      this.setUIFlag({ fetchingList: true });
      try {
        const { data } = await TaskAPI.getAll(params);
        const payload = data.payload || data;
        this.tasks = Array.isArray(payload) ? payload : [];
        if (data.meta) {
          this.setMeta(data.meta);
        }
        return this.tasks;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    async fetchForContact(contactId, params = {}) {
      this.setUIFlag({ fetchingList: true });
      try {
        const { data } = await TaskAPI.getForContact(contactId, params);
        const payload = data.payload || data;
        this.tasks = Array.isArray(payload) ? payload : [];
        if (data.meta) {
          this.setMeta(data.meta);
        }
        return this.tasks;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    async createForContact(contactId, data) {
      this.setUIFlag({ creatingItem: true });
      try {
        const { data: responseData } = await TaskAPI.createForContact(
          contactId,
          data
        );
        const task = responseData.payload || responseData;
        this.tasks.unshift(task);
        return task;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ creatingItem: false });
      }
    },

    async updateTask(taskId, data) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data: responseData } = await TaskAPI.update(taskId, data);
        const updatedTask = responseData.payload || responseData;
        const index = this.tasks.findIndex(t => t.id === taskId);
        if (index !== -1) {
          this.tasks[index] = updatedTask;
        }
        return updatedTask;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async deleteTask(taskId) {
      this.setUIFlag({ deletingItem: true });
      try {
        await TaskAPI.delete(taskId);
        this.tasks = this.tasks.filter(t => t.id !== taskId);
        return taskId;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ deletingItem: false });
      }
    },

    async completeTask(taskId) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data: responseData } = await TaskAPI.complete(taskId);
        const updatedTask = responseData.payload || responseData;
        const index = this.tasks.findIndex(t => t.id === taskId);
        if (index !== -1) {
          this.tasks[index] = updatedTask;
        }
        return updatedTask;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async reopenTask(taskId) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data: responseData } = await TaskAPI.reopen(taskId);
        const updatedTask = responseData.payload || responseData;
        const index = this.tasks.findIndex(t => t.id === taskId);
        if (index !== -1) {
          this.tasks[index] = updatedTask;
        }
        return updatedTask;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    reset() {
      this.tasks = [];
      this.meta = { totalCount: 0, page: 1, totalPages: 1 };
      this.filters = { assigneeId: null, status: null };
    },
  },
});
