/* global axios */
import ApiClient from '../ApiClient';

class TaskAPI extends ApiClient {
  constructor() {
    super('crm', { accountScoped: true });
  }

  getForContact(contactId, params = {}) {
    return axios.get(`${this.url}/contacts/${contactId}/tasks`, { params });
  }

  createForContact(contactId, data) {
    return axios.post(`${this.url}/contacts/${contactId}/tasks`, {
      task: data,
    });
  }

  getAll(params = {}) {
    return axios.get(`${this.url}/tasks`, { params });
  }

  show(taskId) {
    return axios.get(`${this.url}/tasks/${taskId}`);
  }

  update(taskId, data) {
    return axios.patch(`${this.url}/tasks/${taskId}`, { task: data });
  }

  delete(taskId) {
    return axios.delete(`${this.url}/tasks/${taskId}`);
  }

  complete(taskId) {
    return axios.post(`${this.url}/tasks/${taskId}/complete`);
  }

  reopen(taskId) {
    return axios.post(`${this.url}/tasks/${taskId}/reopen`);
  }
}

export default new TaskAPI();
