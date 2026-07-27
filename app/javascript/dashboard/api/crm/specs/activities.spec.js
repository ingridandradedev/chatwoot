import activityAPI from '../activities';
import ApiClient from '../../ApiClient';

describe('#ActivityAPI', () => {
  it('creates correct instance', () => {
    expect(activityAPI).toBeInstanceOf(ApiClient);
    expect(activityAPI).toHaveProperty('getForContact');
    expect(activityAPI).toHaveProperty('createForContact');
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

    it('#getForContact calls correct URL', () => {
      activityAPI.getForContact(42, { page: 2 });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/crm/contacts/42/activities',
        { params: { page: 2 } }
      );
    });

    it('#getForContact calls correct URL with empty params', () => {
      activityAPI.getForContact(7);
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/crm/contacts/7/activities',
        { params: {} }
      );
    });

    it('#createForContact sends POST with correct payload', () => {
      const activityData = { activity_type: 'call', note: 'Follow up call' };
      activityAPI.createForContact(42, activityData);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/crm/contacts/42/activities',
        { activity: activityData }
      );
    });
  });
});
