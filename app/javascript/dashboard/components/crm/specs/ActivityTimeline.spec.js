import { shallowMount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import ActivityTimeline from '../ActivityTimeline.vue';
import { useCrmActivitiesStore } from 'dashboard/stores/crm/activities';

vi.mock('dashboard/api/crm/activities', () => ({
  default: {
    getForContact: vi.fn(() =>
      Promise.resolve({
        data: {
          payload: [],
          meta: { total_count: 0, page: 1, total_pages: 1 },
        },
      })
    ),
  },
}));

const sampleActivities = [
  {
    id: 1,
    activity_type: 'call',
    description: 'Called the client about the proposal',
    user: { name: 'Agent Smith' },
    created_at: '2024-01-15T10:30:00Z',
  },
  {
    id: 2,
    activity_type: 'email',
    description: 'Sent follow-up email',
    user: { name: 'Agent Jones' },
    created_at: '2024-01-14T09:00:00Z',
  },
  {
    id: 3,
    activity_type: 'stage_change',
    description: 'Moved from New to Qualified',
    user: { name: 'Agent Smith' },
    created_at: '2024-01-13T15:00:00Z',
  },
];

const mountComponent = (props = {}) => {
  return shallowMount(ActivityTimeline, {
    props: { contactId: 42, ...props },
  });
};

describe('ActivityTimeline', () => {
  let store;

  beforeEach(() => {
    setActivePinia(createPinia());
    store = useCrmActivitiesStore();
  });

  it('calls fetchForContact on mount with the contactId prop', () => {
    const spy = vi.spyOn(store, 'fetchForContact');
    mountComponent({ contactId: 99 });
    expect(spy).toHaveBeenCalledWith(99, 1);
  });

  it('displays loading text when fetching and no activities exist', () => {
    store.uiFlags.fetchingList = true;
    store.activities = [];
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('Loading activities...');
  });

  it('displays empty state when not fetching and no activities', () => {
    store.uiFlags.fetchingList = false;
    store.activities = [];
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('No activities yet.');
  });

  it('renders activity items with type badge, description, user and timestamp', () => {
    store.activities = sampleActivities;
    store.uiFlags.fetchingList = false;
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('Call');
    expect(wrapper.text()).toContain('Called the client about the proposal');
    expect(wrapper.text()).toContain('Agent Smith');
  });

  it('renders stage_change type badge correctly', () => {
    store.activities = [sampleActivities[2]];
    store.uiFlags.fetchingList = false;
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('Stage Change');
  });

  it('shows Load more button when there are more pages', () => {
    store.activities = sampleActivities;
    store.meta = { totalCount: 40, page: 1, totalPages: 2 };
    store.uiFlags.fetchingList = false;
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('Load more');
  });

  it('hides Load more button when on the last page', () => {
    store.activities = sampleActivities;
    store.meta = { totalCount: 3, page: 1, totalPages: 1 };
    store.uiFlags.fetchingList = false;
    const wrapper = mountComponent();
    expect(wrapper.text()).not.toContain('Load more');
  });

  it('calls fetchForContact with next page when Load more is clicked', async () => {
    store.activities = sampleActivities;
    store.meta = { totalCount: 40, page: 1, totalPages: 2 };
    store.uiFlags.fetchingList = false;
    const spy = vi.spyOn(store, 'fetchForContact');
    const wrapper = mountComponent();

    await wrapper.find('button').trigger('click');
    expect(spy).toHaveBeenCalledWith(42, 2);
  });
});
