import taskAPI from '../tasks';
import ApiClient from '../../ApiClient';

describe('#TaskAPI', () => {
  it('creates correct instance', () => {
    expect(taskAPI).toBeInstanceOf(ApiClient);
    expect(taskAPI).toHaveProperty('getForContact');
    expect(taskAPI).toHaveProperty('createForContact');
    expect(taskAPI).toHaveProperty('getAll');
    expect(taskAPI).toHaveProperty('show');
    expect(taskAPI).toHaveProperty('update');
    expect(taskAPI).toHaveProperty('delete');
    expect(taskAPI).toHaveProperty('complete');
    expect(taskAPI).toHaveProperty('reopen');
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
      taskAPI.getForContact(15, { page: 1 });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/crm/contacts/15/tasks',
        { params: { page: 1 } }
      );
    });

    it('#getForContact calls correct URL with empty params', () => {
      taskAPI.getForContact(15);
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/crm/contacts/15/tasks',
        { params: {} }
      );
    });

    it('#createForContact sends POST with correct payload', () => {
      const taskData = { title: 'Follow up', due_date: '2024-12-01' };
      taskAPI.createForContact(15, taskData);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/crm/contacts/15/tasks',
        { task: taskData }
      );
    });

    it('#getAll calls correct URL', () => {
      taskAPI.getAll({ page: 2, status: 'pending' });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/crm/tasks', {
        params: { page: 2, status: 'pending' },
      });
    });

    it('#getAll calls correct URL with empty params', () => {
      taskAPI.getAll();
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/crm/tasks', {
        params: {},
      });
    });

    it('#show calls correct URL', () => {
      taskAPI.show(8);
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/crm/tasks/8');
    });

    it('#update sends PATCH with correct payload', () => {
      const taskData = { title: 'Updated task', due_date: '2024-12-15' };
      taskAPI.update(8, taskData);
      expect(axiosMock.patch).toHaveBeenCalledWith('/api/v1/crm/tasks/8', {
        task: taskData,
      });
    });

    it('#delete sends DELETE to correct URL', () => {
      taskAPI.delete(8);
      expect(axiosMock.delete).toHaveBeenCalledWith('/api/v1/crm/tasks/8');
    });

    it('#complete sends POST to correct URL', () => {
      taskAPI.complete(8);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/crm/tasks/8/complete'
      );
    });

    it('#reopen sends POST to correct URL', () => {
      taskAPI.reopen(8);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/crm/tasks/8/reopen'
      );
    });
  });
});
