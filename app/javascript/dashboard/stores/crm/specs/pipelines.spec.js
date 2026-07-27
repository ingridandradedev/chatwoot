import { setActivePinia, createPinia } from 'pinia';
import PipelineAPI from 'dashboard/api/crm/pipelines';
import { useCrmPipelinesStore } from '../pipelines';

vi.mock('dashboard/api/crm/pipelines', () => ({
  default: {
    get: vi.fn(),
    show: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => error),
}));

describe('crmPipelines store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('fetches pipelines and populates records state', async () => {
    const pipelines = [
      { id: 1, name: 'Sales Pipeline' },
      { id: 2, name: 'Support Pipeline' },
    ];
    PipelineAPI.get.mockResolvedValue({ data: { payload: pipelines } });

    const store = useCrmPipelinesStore();
    await store.get();

    expect(store.records).toEqual(pipelines);
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('setCurrentPipeline updates currentPipelineId', () => {
    const store = useCrmPipelinesStore();
    store.setCurrentPipeline(5);

    expect(store.currentPipelineId).toBe(5);
  });

  it('setCurrentPipeline coerces string ids to numbers', () => {
    const store = useCrmPipelinesStore();
    store.setCurrentPipeline('3');

    expect(store.currentPipelineId).toBe(3);
  });

  it('getCurrentPipeline returns the correct pipeline', () => {
    const store = useCrmPipelinesStore();
    store.records = [
      { id: 1, name: 'Sales' },
      { id: 2, name: 'Support' },
    ];
    store.currentPipelineId = 2;

    expect(store.getCurrentPipeline).toEqual({ id: 2, name: 'Support' });
  });

  it('getCurrentPipeline returns null when no pipeline is selected', () => {
    const store = useCrmPipelinesStore();
    store.records = [{ id: 1, name: 'Sales' }];
    store.currentPipelineId = null;

    expect(store.getCurrentPipeline).toBeNull();
  });
});
