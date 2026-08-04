<script setup>
import { computed } from 'vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
  cardFields: {
    type: Array,
    default: () => ['name', 'email', 'phone_number'],
  },
});

const contact = computed(() => props.deal.contact || {});

const formattedValue = computed(() => {
  if (props.deal.value == null || props.deal.value === 0) return '';
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(props.deal.value);
});

const initials = computed(() => {
  const name = contact.value.name || '';
  return name
    .split(' ')
    .slice(0, 2)
    .map(w => w[0])
    .join('')
    .toUpperCase();
});

const showField = field => props.cardFields.includes(field);

// Standard fields with labels and icons
const STANDARD_FIELDS = {
  email: { icon: 'i-lucide-mail', getValue: () => contact.value.email },
  phone_number: { icon: 'i-lucide-phone', getValue: () => contact.value.phone_number },
  company: { icon: 'i-lucide-building-2', getValue: () => contact.value.company },
  deal_value: { icon: 'i-lucide-banknote', getValue: () => formattedValue.value },
  deal_title: { icon: 'i-lucide-tag', getValue: () => props.deal.title },
};

// Get custom attribute fields to display
const visibleCustomAttributes = computed(() => {
  const customAttrs = contact.value.custom_attributes || {};
  return props.cardFields
    .filter(field => !['name', 'email', 'phone_number', 'company', 'deal_value', 'deal_title'].includes(field))
    .map(field => ({
      key: field,
      value: customAttrs[field],
    }))
    .filter(attr => attr.value != null && attr.value !== '');
});
</script>

<template>
  <div
    class="deal-card p-3 bg-white dark:bg-n-slate-3 rounded-lg shadow-sm border border-n-weak cursor-pointer hover:border-n-slate-8 transition-colors"
    :data-deal-id="deal.id"
  >
    <!-- Contact header with avatar — always visible -->
    <div class="flex items-center gap-2">
      <div
        v-if="contact.thumbnail"
        class="w-8 h-8 rounded-full bg-cover bg-center flex-shrink-0"
        :style="{ backgroundImage: `url(${contact.thumbnail})` }"
      />
      <div
        v-else
        class="w-8 h-8 rounded-full bg-n-iris-9 flex items-center justify-center flex-shrink-0"
      >
        <span class="text-xs font-medium text-white">{{ initials }}</span>
      </div>
      <div class="min-w-0 flex-1">
        <p v-if="showField('name')" class="text-sm font-medium text-n-slate-12 truncate">
          {{ contact.name || 'Unnamed' }}
        </p>
        <p v-if="showField('company') && contact.company" class="text-xs text-n-slate-10 truncate">
          {{ contact.company }}
        </p>
      </div>
    </div>

    <!-- Configurable standard fields -->
    <div class="mt-2 space-y-0.5">
      <p v-if="showField('email') && contact.email" class="text-xs text-n-slate-11 truncate flex items-center gap-1">
        <span class="i-lucide-mail w-3 h-3 flex-shrink-0" />
        {{ contact.email }}
      </p>
      <p v-if="showField('phone_number') && contact.phone_number" class="text-xs text-n-slate-11 truncate flex items-center gap-1">
        <span class="i-lucide-phone w-3 h-3 flex-shrink-0" />
        {{ contact.phone_number }}
      </p>
    </div>

    <!-- Custom attributes -->
    <div v-if="visibleCustomAttributes.length > 0" class="mt-1.5 space-y-0.5">
      <p
        v-for="attr in visibleCustomAttributes"
        :key="attr.key"
        class="text-xs text-n-slate-10 truncate flex items-center gap-1"
      >
        <span class="i-lucide-tag w-3 h-3 flex-shrink-0" />
        <span class="font-medium">{{ attr.key }}:</span> {{ attr.value }}
      </p>
    </div>

    <!-- Deal metadata -->
    <div v-if="(showField('deal_title') && deal.title) || (showField('deal_value') && formattedValue)" class="mt-2 pt-2 border-t border-n-weak">
      <p v-if="showField('deal_title') && deal.title" class="text-xs text-n-slate-11 truncate">
        {{ deal.title }}
      </p>
      <p v-if="showField('deal_value') && formattedValue" class="text-xs font-semibold text-green-600 dark:text-green-400">
        {{ formattedValue }}
      </p>
    </div>
  </div>
</template>
