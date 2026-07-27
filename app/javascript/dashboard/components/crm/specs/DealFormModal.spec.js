import { shallowMount } from '@vue/test-utils';
import DealFormModal from '../DealFormModal.vue';

vi.mock('dashboard/api/contacts', () => ({
  default: {
    search: vi.fn(() =>
      Promise.resolve({
        data: {
          payload: [
            { id: 1, name: 'Alice', email: 'alice@example.com' },
            { id: 2, name: 'Bob', email: 'bob@example.com' },
          ],
        },
      })
    ),
  },
}));

const defaultProps = {
  show: true,
  pipelineId: 1,
  stages: [
    { id: 10, name: 'New' },
    { id: 20, name: 'Qualified' },
    { id: 30, name: 'Closed Won' },
  ],
  deal: null,
};

const mountComponent = (props = {}) => {
  return shallowMount(DealFormModal, {
    props: { ...defaultProps, ...props },
  });
};

describe('DealFormModal', () => {
  it('renders the modal with "New Deal" title when no deal prop', () => {
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('New Deal');
  });

  it('renders the modal with "Edit Deal" title when deal prop is provided', () => {
    const wrapper = mountComponent({
      deal: {
        contact_id: 1,
        contact_name: 'Alice',
        stage_id: 10,
        title: 'Existing deal',
        value: 5000,
      },
    });
    expect(wrapper.text()).toContain('Edit Deal');
  });

  it('pre-fills form fields when editing a deal', () => {
    const wrapper = mountComponent({
      deal: {
        contact_id: 1,
        contact_name: 'Alice',
        stage_id: 20,
        title: 'Existing deal',
        value: 1500.5,
      },
    });

    const { contactId, stageId, title, value } = wrapper.vm;
    expect(contactId).toBe(1);
    expect(stageId).toBe(20);
    expect(title).toBe('Existing deal');
    expect(value).toBe(1500.5);
  });

  it('disables submit button when contact is not selected', () => {
    const wrapper = mountComponent();
    // By default no contact is selected
    expect(wrapper.vm.isValid).toBe(false);
  });

  it('enables submit button when contact and stage are selected', async () => {
    const wrapper = mountComponent();
    wrapper.vm.contactId = 1;
    wrapper.vm.stageId = 10;
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.isValid).toBe(true);
  });

  it('emits submit event with correct payload on form submit', async () => {
    const wrapper = mountComponent();
    wrapper.vm.contactId = 1;
    wrapper.vm.stageId = 20;
    wrapper.vm.title = 'Test Deal';
    wrapper.vm.value = 3000;
    await wrapper.vm.$nextTick();

    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')).toBeTruthy();
    expect(wrapper.emitted('submit')[0][0]).toEqual({
      contact_id: 1,
      stage_id: 20,
      title: 'Test Deal',
      value: 3000,
      pipeline_id: 1,
    });
  });

  it('emits close event when cancel button is clicked', async () => {
    const wrapper = mountComponent();
    // The cancel button uses NextButton with @click.prevent="closeModal"
    // Since NextButton is stubbed, we call closeModal directly
    wrapper.vm.closeModal();
    expect(wrapper.emitted('close')).toBeTruthy();
  });

  it('pre-selects the first stage when no deal is provided', () => {
    const wrapper = mountComponent();
    expect(wrapper.vm.stageId).toBe(10);
  });

  it('renders all stage options in the stage selector', () => {
    const wrapper = mountComponent();
    const options = wrapper.findAll('option');
    expect(options).toHaveLength(3);
    expect(options[0].text()).toBe('New');
    expect(options[1].text()).toBe('Qualified');
    expect(options[2].text()).toBe('Closed Won');
  });

  it('does not emit submit when form is invalid', async () => {
    const wrapper = mountComponent();
    // contactId is null, so isValid is false
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('submit')).toBeFalsy();
  });

  it('emits null for value when value field is empty', async () => {
    const wrapper = mountComponent();
    wrapper.vm.contactId = 1;
    wrapper.vm.stageId = 10;
    wrapper.vm.title = '';
    wrapper.vm.value = null;
    await wrapper.vm.$nextTick();

    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')[0][0]).toEqual({
      contact_id: 1,
      stage_id: 10,
      title: null,
      value: null,
      pipeline_id: 1,
    });
  });
});
