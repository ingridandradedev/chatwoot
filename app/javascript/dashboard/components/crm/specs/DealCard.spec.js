import { shallowMount } from '@vue/test-utils';
import DealCard from '../DealCard.vue';

const createDeal = (overrides = {}) => ({
  id: 1,
  title: 'Enterprise Plan',
  contact: { name: 'John Doe' },
  value: 5000,
  ...overrides,
});

const mountComponent = (props = {}) => {
  return shallowMount(DealCard, {
    props: {
      deal: createDeal(),
      ...props,
    },
  });
};

describe('DealCard', () => {
  it('displays contact name from contact object', () => {
    const wrapper = mountComponent({
      deal: createDeal({ contact: { name: 'Alice Smith' } }),
    });
    expect(wrapper.text()).toContain('Alice Smith');
  });

  it('falls back to contact_name when contact object is missing', () => {
    const wrapper = mountComponent({
      deal: createDeal({ contact: null, contact_name: 'Bob Jones' }),
    });
    expect(wrapper.text()).toContain('Bob Jones');
  });

  it('displays formatted currency value when value is present', () => {
    const wrapper = mountComponent({
      deal: createDeal({ value: 2500 }),
    });
    // Value should be rendered as currency (BRL format)
    const text = wrapper.text();
    expect(text).toMatch(/2[.,]500/);
  });

  it('does not display value when value is null', () => {
    const wrapper = mountComponent({
      deal: createDeal({ value: null }),
    });
    const valueParagraphs = wrapper.findAll('.text-green-600, .dark\\:text-green-400');
    // The v-if on the value paragraph means it should not render
    expect(wrapper.find('.text-green-600').exists()).toBe(false);
  });

  it('does not display value when value is 0', () => {
    const wrapper = mountComponent({
      deal: createDeal({ value: 0 }),
    });
    expect(wrapper.find('.text-green-600').exists()).toBe(false);
  });

  it('displays deal title when present', () => {
    const wrapper = mountComponent({
      deal: createDeal({ title: 'Premium Subscription' }),
    });
    expect(wrapper.text()).toContain('Premium Subscription');
  });

  it('sets data-deal-id attribute on root element', () => {
    const wrapper = mountComponent({
      deal: createDeal({ id: 99 }),
    });
    expect(wrapper.attributes('data-deal-id')).toBe('99');
  });
});
