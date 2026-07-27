import { shallowMount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import ActivityForm from '../ActivityForm.vue';
import { useCrmActivitiesStore } from 'dashboard/stores/crm/activities';

vi.mock('dashboard/api/crm/activities', () => ({
  default: {
    createForContact: vi.fn(() =>
      Promise.resolve({
        data: {
          id: 10,
          activity_type: 'call',
          description: 'Test call',
        },
      })
    ),
  },
}));

const mountComponent = (props = {}) => {
  return shallowMount(ActivityForm, {
    props: { contactId: 42, ...props },
  });
};

describe('ActivityForm', () => {
  let store;

  beforeEach(() => {
    setActivePinia(createPinia());
    store = useCrmActivitiesStore();
  });

  it('renders the form with type selector and description textarea', () => {
    const wrapper = mountComponent();
    expect(wrapper.find('select').exists()).toBe(true);
    expect(wrapper.find('textarea').exists()).toBe(true);
    expect(wrapper.find('button[type="submit"]').exists()).toBe(true);
  });

  it('renders only manual activity types (call, email, meeting, note)', () => {
    const wrapper = mountComponent();
    const options = wrapper.findAll('option');
    // first option is the disabled placeholder
    const values = options.map(o => o.element.value);
    expect(values).toContain('call');
    expect(values).toContain('email');
    expect(values).toContain('meeting');
    expect(values).toContain('note');
    expect(values).not.toContain('stage_change');
    expect(values).not.toContain('task_completed');
  });

  it('disables submit button when type is not selected', async () => {
    const wrapper = mountComponent();
    await wrapper.find('textarea').setValue('Some description');
    expect(wrapper.find('button[type="submit"]').attributes('disabled')).toBeDefined();
  });

  it('disables submit button when description is empty', async () => {
    const wrapper = mountComponent();
    await wrapper.find('select').setValue('call');
    expect(wrapper.find('button[type="submit"]').attributes('disabled')).toBeDefined();
  });

  it('enables submit button when both type and description are filled', async () => {
    const wrapper = mountComponent();
    await wrapper.find('select').setValue('call');
    await wrapper.find('textarea').setValue('Called the client');
    expect(wrapper.find('button[type="submit"]').attributes('disabled')).toBeUndefined();
  });

  it('calls createForContact on form submit with correct payload', async () => {
    const spy = vi
      .spyOn(store, 'createForContact')
      .mockResolvedValue({ id: 10, activity_type: 'call', description: 'Test' });

    const wrapper = mountComponent();
    await wrapper.find('select').setValue('meeting');
    await wrapper.find('textarea').setValue('Discussed contract terms');
    await wrapper.find('form').trigger('submit');

    expect(spy).toHaveBeenCalledWith(42, {
      activity_type: 'meeting',
      description: 'Discussed contract terms',
    });
  });

  it('emits created event after successful creation', async () => {
    const activity = { id: 10, activity_type: 'note', description: 'A note' };
    vi.spyOn(store, 'createForContact').mockResolvedValue(activity);

    const wrapper = mountComponent();
    await wrapper.find('select').setValue('note');
    await wrapper.find('textarea').setValue('A note');
    await wrapper.find('form').trigger('submit');

    // Wait for async
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('created')).toBeTruthy();
    expect(wrapper.emitted('created')[0][0]).toEqual(activity);
  });

  it('resets form after successful creation', async () => {
    vi.spyOn(store, 'createForContact').mockResolvedValue({
      id: 10,
      activity_type: 'call',
      description: 'Test',
    });

    const wrapper = mountComponent();
    await wrapper.find('select').setValue('call');
    await wrapper.find('textarea').setValue('Test call');
    await wrapper.find('form').trigger('submit');
    await wrapper.vm.$nextTick();

    expect(wrapper.find('select').element.value).toBe('');
    expect(wrapper.find('textarea').element.value).toBe('');
  });

  it('does not submit if form is invalid', async () => {
    const spy = vi.spyOn(store, 'createForContact');
    const wrapper = mountComponent();
    await wrapper.find('form').trigger('submit');
    expect(spy).not.toHaveBeenCalled();
  });
});
