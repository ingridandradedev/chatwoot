/* global axios */
import ApiClient from '../ApiClient';

class ActivityAPI extends ApiClient {
  constructor() {
    super('crm/contacts', { accountScoped: true });
  }

  getForContact(contactId, params = {}) {
    return axios.get(`${this.url}/${contactId}/activities`, { params });
  }

  createForContact(contactId, data) {
    return axios.post(`${this.url}/${contactId}/activities`, {
      activity: data,
    });
  }
}

export default new ActivityAPI();
