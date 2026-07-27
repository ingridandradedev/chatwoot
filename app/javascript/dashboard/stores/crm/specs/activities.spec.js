import { setActivePinia, createPinia } from 'pinia';
import ActivityAPI from 'dashboard/api/crm/activities';
import { useCrmActivitiesStore } from '../activities';

vi.mock('dashboard/api/crm/activities', () => ({
  default: {
    getForContact: vi.fn(),
    createForContact: vi.fn(),
  },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => error),
}));

describe('crmActivities store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  describe('fetchForContact', () => {
    it('page 1 replaces activities', async () => {
      const activities = [
        { id: 1, type: 'call' },
        { id: 2, type: 'email' },
      ];
      ActivityAPI.getForContact.mockResolvedValue({
        data: {
          payload: activities,
          meta: { total_count: 5, page: 1, total_pages: 3 },
        },
      });

      const store = useCrmActivitiesStore();
      store.activities = [{ id: 99, type: 'old' }];

      await store.fetchForContact(1, 1);

      expect(store.activities).toEqual(activities);
      expect(store.meta).toEqual({
        totalCount: 5,
        page: 1,
        totalPages: 3,
      });
      expect(store.uiFlags.fetchingList).toBe(false);
    });

    it('page 2+ appends activities', async () => {
      const existingActivities = [
        { id: 1, type: 'call' },
        { id: 2, type: 'email' },
      ];
      const newActivities = [
        { id: 3, type: 'meeting' },
        { id: 4, type: 'note' },
      ];
      ActivityAPI.getForContact.mockResolvedValue({
        data: {
          payload: newActivities,
          meta: { total_count: 10, page: 2, total_pages: 5 },
        },
      });

      const store = useCrmActivitiesStore();
      store.activities = existingActivities;

      await store.fetchForContact(1, 2);

      expect(store.activities).toEqual([
        ...existingActivities,
        ...newActivities,
      ]);
      expect(store.meta).toEqual({
        totalCount: 10,
        page: 2,
        totalPages: 5,
      });
    });
  });

  describe('createForContact', () => {
    it('prepends new activity', async () => {
      const newActivity = { id: 5, type: 'call', note: 'Follow-up' };
      ActivityAPI.createForContact.mockResolvedValue({
        data: { payload: newActivity },
      });

      const store = useCrmActivitiesStore();
      store.activities = [{ id: 1, type: 'email' }];

      const result = await store.createForContact(1, { type: 'call' });

      expect(result).toEqual(newActivity);
      expect(store.activities[0]).toEqual(newActivity);
      expect(store.activities).toHaveLength(2);
      expect(store.uiFlags.creatingItem).toBe(false);
    });
  });

  describe('reset', () => {
    it('clears state', () => {
      const store = useCrmActivitiesStore();
      store.activities = [{ id: 1 }, { id: 2 }];
      store.meta = { totalCount: 10, page: 3, totalPages: 5 };

      store.reset();

      expect(store.activities).toEqual([]);
      expect(store.meta).toEqual({
        totalCount: 0,
        page: 1,
        totalPages: 1,
      });
    });
  });
});
