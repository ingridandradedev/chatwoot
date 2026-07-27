import { setActivePinia, createPinia } from 'pinia';
import TaskAPI from 'dashboard/api/crm/tasks';
import { useCrmTasksStore } from '../tasks';

vi.mock('dashboard/api/crm/tasks', () => ({
  default: {
    getAll: vi.fn(),
    getForContact: vi.fn(),
    createForContact: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    complete: vi.fn(),
    reopen: vi.fn(),
  },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => error),
}));

describe('crmTasks store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  describe('fetchAll', () => {
    it('populates tasks', async () => {
      const tasks = [
        { id: 1, title: 'Call client', status: 'open', assignee_id: 10 },
        { id: 2, title: 'Send proposal', status: 'open', assignee_id: 20 },
      ];
      TaskAPI.getAll.mockResolvedValue({
        data: { payload: tasks, meta: { total_count: 2, page: 1, total_pages: 1 } },
      });

      const store = useCrmTasksStore();
      await store.fetchAll({ page: 1 });

      expect(store.tasks).toEqual(tasks);
      expect(store.meta.totalCount).toBe(2);
      expect(store.uiFlags.fetchingList).toBe(false);
    });
  });

  describe('fetchForContact', () => {
    it('populates tasks', async () => {
      const tasks = [
        { id: 3, title: 'Follow up', status: 'open', assignee_id: 10 },
      ];
      TaskAPI.getForContact.mockResolvedValue({
        data: { payload: tasks, meta: { total_count: 1, page: 1, total_pages: 1 } },
      });

      const store = useCrmTasksStore();
      await store.fetchForContact(5, { page: 1 });

      expect(store.tasks).toEqual(tasks);
      expect(TaskAPI.getForContact).toHaveBeenCalledWith(5, { page: 1 });
      expect(store.uiFlags.fetchingList).toBe(false);
    });
  });

  describe('setFilters', () => {
    it('updates filter state', () => {
      const store = useCrmTasksStore();

      store.setFilters({ assigneeId: 10, status: 'completed' });

      expect(store.filters.assigneeId).toBe(10);
      expect(store.filters.status).toBe('completed');
    });

    it('updates partial filters without clearing others', () => {
      const store = useCrmTasksStore();
      store.filters = { assigneeId: 10, status: 'open' };

      store.setFilters({ status: 'completed' });

      expect(store.filters.assigneeId).toBe(10);
      expect(store.filters.status).toBe('completed');
    });
  });

  describe('getFilteredTasks', () => {
    it('respects assigneeId filter', () => {
      const store = useCrmTasksStore();
      store.tasks = [
        { id: 1, title: 'Task A', assignee_id: 10, status: 'open' },
        { id: 2, title: 'Task B', assignee_id: 20, status: 'open' },
        { id: 3, title: 'Task C', assignee_id: 10, status: 'completed' },
      ];
      store.filters.assigneeId = 10;

      expect(store.getFilteredTasks).toEqual([
        { id: 1, title: 'Task A', assignee_id: 10, status: 'open' },
        { id: 3, title: 'Task C', assignee_id: 10, status: 'completed' },
      ]);
    });

    it('respects status filter', () => {
      const store = useCrmTasksStore();
      store.tasks = [
        { id: 1, title: 'Task A', assignee_id: 10, status: 'open' },
        { id: 2, title: 'Task B', assignee_id: 20, status: 'completed' },
      ];
      store.filters.status = 'completed';

      expect(store.getFilteredTasks).toEqual([
        { id: 2, title: 'Task B', assignee_id: 20, status: 'completed' },
      ]);
    });

    it('respects both assigneeId and status filters', () => {
      const store = useCrmTasksStore();
      store.tasks = [
        { id: 1, title: 'Task A', assignee_id: 10, status: 'open' },
        { id: 2, title: 'Task B', assignee_id: 10, status: 'completed' },
        { id: 3, title: 'Task C', assignee_id: 20, status: 'completed' },
      ];
      store.filters.assigneeId = 10;
      store.filters.status = 'completed';

      expect(store.getFilteredTasks).toEqual([
        { id: 2, title: 'Task B', assignee_id: 10, status: 'completed' },
      ]);
    });
  });

  describe('completeTask', () => {
    it('updates task in array', async () => {
      const completedTask = { id: 1, title: 'Task A', status: 'completed' };
      TaskAPI.complete.mockResolvedValue({ data: { payload: completedTask } });

      const store = useCrmTasksStore();
      store.tasks = [{ id: 1, title: 'Task A', status: 'open' }];

      await store.completeTask(1);

      expect(store.tasks[0]).toEqual(completedTask);
      expect(store.uiFlags.updatingItem).toBe(false);
    });
  });

  describe('reopenTask', () => {
    it('updates task in array', async () => {
      const reopenedTask = { id: 1, title: 'Task A', status: 'open' };
      TaskAPI.reopen.mockResolvedValue({ data: { payload: reopenedTask } });

      const store = useCrmTasksStore();
      store.tasks = [{ id: 1, title: 'Task A', status: 'completed' }];

      await store.reopenTask(1);

      expect(store.tasks[0]).toEqual(reopenedTask);
      expect(store.uiFlags.updatingItem).toBe(false);
    });
  });

  describe('deleteTask', () => {
    it('removes task from array', async () => {
      TaskAPI.delete.mockResolvedValue({});

      const store = useCrmTasksStore();
      store.tasks = [
        { id: 1, title: 'Task A' },
        { id: 2, title: 'Task B' },
      ];

      await store.deleteTask(1);

      expect(store.tasks).toEqual([{ id: 2, title: 'Task B' }]);
      expect(store.uiFlags.deletingItem).toBe(false);
    });
  });
});
