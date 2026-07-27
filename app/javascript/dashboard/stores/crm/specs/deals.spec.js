import { setActivePinia, createPinia } from 'pinia';
import DealAPI from 'dashboard/api/crm/deals';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import { useCrmDealsStore } from '../deals';

vi.mock('dashboard/api/crm/deals', () => ({
  default: {
    getForPipeline: vi.fn(),
    moveToStage: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => error),
}));

describe('crmDeals store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  describe('fetchForPipeline', () => {
    it('groups deals by stage_id', async () => {
      const deals = [
        { id: 1, name: 'Deal A', stage_id: 10 },
        { id: 2, name: 'Deal B', stage_id: 20 },
        { id: 3, name: 'Deal C', stage_id: 10 },
      ];
      DealAPI.getForPipeline.mockResolvedValue({
        data: { payload: deals },
      });

      const store = useCrmDealsStore();
      await store.fetchForPipeline(1);

      expect(store.dealsByStage[10]).toEqual([
        { id: 1, name: 'Deal A', stage_id: 10 },
        { id: 3, name: 'Deal C', stage_id: 10 },
      ]);
      expect(store.dealsByStage[20]).toEqual([
        { id: 2, name: 'Deal B', stage_id: 20 },
      ]);
      expect(store.uiFlags.fetchingList).toBe(false);
    });
  });

  describe('moveToStage', () => {
    it('optimistically moves deal between stages', async () => {
      DealAPI.moveToStage.mockResolvedValue({ data: {} });

      const store = useCrmDealsStore();
      store.dealsByStage = {
        10: [{ id: 1, name: 'Deal A', stage_id: 10 }],
        20: [],
      };

      await store.moveToStage(1, 1, 10, 20);

      expect(store.dealsByStage[10]).toEqual([]);
      expect(store.dealsByStage[20]).toEqual([
        { id: 1, name: 'Deal A', stage_id: 20 },
      ]);
    });

    it('reverts on API failure', async () => {
      const error = new Error('Network error');
      DealAPI.moveToStage.mockRejectedValue(error);

      const store = useCrmDealsStore();
      store.dealsByStage = {
        10: [{ id: 1, name: 'Deal A', stage_id: 10 }],
        20: [],
      };

      await store.moveToStage(1, 1, 10, 20);

      expect(store.dealsByStage[10]).toEqual([
        { id: 1, name: 'Deal A', stage_id: 10 },
      ]);
      expect(store.dealsByStage[20]).toEqual([]);
      expect(throwErrorMessage).toHaveBeenCalledWith(error);
    });
  });

  describe('createDeal', () => {
    it('adds deal to correct stage bucket', async () => {
      const newDeal = { id: 5, name: 'New Deal', stage_id: 10 };
      DealAPI.create.mockResolvedValue({ data: { payload: newDeal } });

      const store = useCrmDealsStore();
      store.dealsByStage = { 10: [] };

      const result = await store.createDeal(1, { name: 'New Deal' });

      expect(result).toEqual(newDeal);
      expect(store.dealsByStage[10]).toEqual([newDeal]);
      expect(store.uiFlags.creatingItem).toBe(false);
    });
  });

  describe('deleteDeal', () => {
    it('removes deal from stage bucket', async () => {
      DealAPI.delete.mockResolvedValue({});

      const store = useCrmDealsStore();
      store.dealsByStage = {
        10: [
          { id: 1, name: 'Deal A', stage_id: 10 },
          { id: 2, name: 'Deal B', stage_id: 10 },
        ],
      };

      await store.deleteDeal(1, 1);

      expect(store.dealsByStage[10]).toEqual([
        { id: 2, name: 'Deal B', stage_id: 10 },
      ]);
      expect(store.uiFlags.deletingItem).toBe(false);
    });
  });
});
