import { shallowMount } from '@vue/test-utils';
import KanbanColumn from '../KanbanColumn.vue';

vi.mock('vuedraggable', () => ({
  default: {
    name: 'Draggable',
    template:
      '<div :data-stage-id="$attrs[\'data-stage-id\']"><slot name="item" v-for="el in list" :element="el" /></div>',
    props: ['list', 'group', 'itemKey', 'animation', 'ghostClass'],
    emits: ['end'],
  },
}));

const createStage = (overrides = {}) => ({
  id: 1,
  name: 'Qualification',
  ...overrides,
});

const createDeals = (count = 3) =>
  Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    title: `Deal ${i + 1}`,
    contact: { name: `Contact ${i + 1}` },
    value: (i + 1) * 1000,
  }));

const mountComponent = (props = {}) => {
  return shallowMount(KanbanColumn, {
    props: {
      stage: createStage(),
      deals: createDeals(),
      ...props,
    },
    global: {
      stubs: {
        Draggable: {
          template:
            '<div :data-stage-id="$attrs[\'data-stage-id\']"><slot name="item" v-for="el in list" :element="el" /></div>',
          props: ['list', 'group', 'itemKey', 'animation', 'ghostClass'],
        },
      },
    },
  });
};

describe('KanbanColumn', () => {
  it('renders stage name and deal count in header', () => {
    const wrapper = mountComponent({
      stage: createStage({ name: 'Negotiation' }),
      deals: createDeals(5),
    });
    const header = wrapper.find('header');
    expect(header.text()).toContain('Negotiation');
    expect(header.text()).toContain('(5)');
  });

  it('renders with zero deals showing count as 0', () => {
    const wrapper = mountComponent({
      stage: createStage({ name: 'New' }),
      deals: [],
    });
    const header = wrapper.find('header');
    expect(header.text()).toContain('New');
    expect(header.text()).toContain('(0)');
  });

  it('emits deal-moved when drag ends to a different stage', () => {
    const wrapper = mountComponent({
      stage: createStage({ id: 1 }),
      deals: createDeals(2),
    });

    // Simulate the onDragEnd handler directly
    const toEl = document.createElement('div');
    toEl.dataset.stageId = '2';
    const fromEl = document.createElement('div');
    fromEl.dataset.stageId = '1';
    const itemEl = document.createElement('div');
    itemEl.dataset.dealId = '42';

    const evt = {
      to: toEl,
      from: fromEl,
      item: itemEl,
      oldIndex: 0,
      newIndex: 0,
    };

    wrapper.vm.onDragEnd(evt);

    expect(wrapper.emitted('deal-moved')).toBeTruthy();
    expect(wrapper.emitted('deal-moved')[0][0]).toEqual({
      dealId: 42,
      fromStageId: 1,
      toStageId: 2,
    });
  });

  it('does not emit deal-moved when drag ends in the same stage', () => {
    const wrapper = mountComponent({
      stage: createStage({ id: 1 }),
      deals: createDeals(2),
    });

    const el = document.createElement('div');
    el.dataset.stageId = '1';
    const itemEl = document.createElement('div');
    itemEl.dataset.dealId = '5';

    const evt = {
      to: el,
      from: el,
      item: itemEl,
      oldIndex: 0,
      newIndex: 1,
    };

    wrapper.vm.onDragEnd(evt);

    expect(wrapper.emitted('deal-moved')).toBeFalsy();
  });
});
