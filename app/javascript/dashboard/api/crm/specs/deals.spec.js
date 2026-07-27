import dealAPI from '../deals';
import ApiClient from '../../ApiClient';

describe('#DealAPI', () => {
  it('creates correct instance', () => {
    expect(dealAPI).toBeInstanceOf(ApiClient);
    expect(dealAPI).toHaveProperty('getForPipeline');
    expect(dealAPI).toHaveProperty('moveToStage');
    expect(dealAPI).toHaveProperty('create');
    expect(dealAPI).toHaveProperty('update');
    expect(dealAPI).toHaveProperty('delete');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#getForPipeline calls correct URL', () => {
      dealAPI.getForPipeline(5, { page: 1, status: 'open' });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/crm/pipelines/5/deals',
        { params: { page: 1, status: 'open' } }
      );
    });

    it('#getForPipeline calls correct URL with empty params', () => {
      dealAPI.getForPipeline(3);
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/crm/pipelines/3/deals',
        { params: {} }
      );
    });

    it('#moveToStage sends PATCH with correct payload', () => {
      dealAPI.moveToStage(2, 10, 7);
      expect(axiosMock.patch).toHaveBeenCalledWith(
        '/api/v1/crm/pipelines/2/deals/10',
        { deal: { stage_id: 7 } }
      );
    });

    it('#create sends POST with correct payload', () => {
      const dealData = { name: 'New Deal', amount: 5000 };
      dealAPI.create(2, dealData);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/crm/pipelines/2/deals',
        { deal: dealData }
      );
    });

    it('#update sends PATCH with correct payload', () => {
      const dealData = { name: 'Updated Deal', amount: 7500 };
      dealAPI.update(2, 10, dealData);
      expect(axiosMock.patch).toHaveBeenCalledWith(
        '/api/v1/crm/pipelines/2/deals/10',
        { deal: dealData }
      );
    });

    it('#delete sends DELETE to correct URL', () => {
      dealAPI.delete(2, 10);
      expect(axiosMock.delete).toHaveBeenCalledWith(
        '/api/v1/crm/pipelines/2/deals/10'
      );
    });
  });
});
