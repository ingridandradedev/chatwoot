import { shallowMount } from '@vue/test-utils';
import TaskCard from '../TaskCard.vue';

const createTask = (overrides = {}) => ({
  id: 1,
  title: 'Follow up with client',
  status: 'pending',
  priority: 'high',
  due_date: '2025-03-15',
  assignee: { name: 'Jane Doe', email: 'jane@example.com' },
  ...overrides,
});

const mountComponent = (props = {}) => {
  return shallowMount(TaskCard, {
    props: {
      task: createTask(),
      ...props,
    },
  });
};

describe('TaskCard', () => {
  it('renders task title', () => {
    const wrapper = mountComponent({
      task: createTask({ title: 'Send proposal' }),
    });
    expect(wrapper.text()).toContain('Send proposal');
  });

  it('renders assignee name', () => {
    const wrapper = mountComponent({
      task: createTask({ assignee: { name: 'Alice', email: 'alice@test.com' } }),
    });
    expect(wrapper.text()).toContain('Alice');
  });

  it('renders assignee_name fallback when assignee object is absent', () => {
    const wrapper = mountComponent({
      task: createTask({ assignee: null, assignee_name: 'Bob' }),
    });
    expect(wrapper.text()).toContain('Bob');
  });

  it('renders priority badge with correct label', () => {
    const wrapper = mountComponent({
      task: createTask({ priority: 'high' }),
    });
    expect(wrapper.text()).toContain('High');
  });

  it('renders medium priority badge', () => {
    const wrapper = mountComponent({
      task: createTask({ priority: 'medium' }),
    });
    expect(wrapper.text()).toContain('Medium');
  });

  it('renders low priority badge', () => {
    const wrapper = mountComponent({
      task: createTask({ priority: 'low' }),
    });
    expect(wrapper.text()).toContain('Low');
  });

  it('shows complete button for pending tasks', () => {
    const wrapper = mountComponent({
      task: createTask({ status: 'pending' }),
    });
    const completeBtn = wrapper.find('button[title="Mark as complete"]');
    expect(completeBtn.exists()).toBe(true);
    expect(wrapper.find('button[title="Reopen task"]').exists()).toBe(false);
  });

  it('shows reopen button for completed tasks', () => {
    const wrapper = mountComponent({
      task: createTask({ status: 'completed' }),
    });
    const reopenBtn = wrapper.find('button[title="Reopen task"]');
    expect(reopenBtn.exists()).toBe(true);
    expect(wrapper.find('button[title="Mark as complete"]').exists()).toBe(false);
  });

  it('emits complete event with task id when complete button clicked', async () => {
    const wrapper = mountComponent({
      task: createTask({ id: 7, status: 'pending' }),
    });
    await wrapper.find('button[title="Mark as complete"]').trigger('click');
    expect(wrapper.emitted('complete')).toBeTruthy();
    expect(wrapper.emitted('complete')[0][0]).toBe(7);
  });

  it('emits reopen event with task id when reopen button clicked', async () => {
    const wrapper = mountComponent({
      task: createTask({ id: 12, status: 'completed' }),
    });
    await wrapper.find('button[title="Reopen task"]').trigger('click');
    expect(wrapper.emitted('reopen')).toBeTruthy();
    expect(wrapper.emitted('reopen')[0][0]).toBe(12);
  });

  it('shows overdue badge when status is overdue', () => {
    const wrapper = mountComponent({
      task: createTask({ status: 'overdue' }),
    });
    expect(wrapper.text()).toContain('Overdue');
  });

  it('applies red border when task is overdue', () => {
    const wrapper = mountComponent({
      task: createTask({ status: 'overdue' }),
    });
    expect(wrapper.classes()).toContain('border-red-300');
  });

  it('does not apply red border when task is not overdue', () => {
    const wrapper = mountComponent({
      task: createTask({ status: 'pending' }),
    });
    expect(wrapper.classes()).not.toContain('border-red-300');
  });

  it('applies line-through style on title when completed', () => {
    const wrapper = mountComponent({
      task: createTask({ status: 'completed' }),
    });
    const title = wrapper.find('.line-through');
    expect(title.exists()).toBe(true);
  });

  it('does not apply line-through style on title when pending', () => {
    const wrapper = mountComponent({
      task: createTask({ status: 'pending' }),
    });
    const title = wrapper.find('.line-through');
    expect(title.exists()).toBe(false);
  });
});
