<script setup>
import { computed } from 'vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
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
</script>

<template>
  <div
    class="deal-card p-3 bg-white dark:bg-n-slate-3 rounded-lg shadow-sm border border-n-weak cursor-grab hover:border-n-slate-8 transition-colors"
    :data-deal-id="deal.id"
  >
    <!-- Contact header with avatar -->
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
        <p class="text-sm font-medium text-n-slate-12 truncate">
          {{ contact.name || 'Unnamed' }}
        </p>
        <p v-if="contact.company" class="text-xs text-n-slate-10 truncate">
          {{ contact.company }}
        </p>
      </div>
    </div>

    <!-- Contact details -->
    <div class="mt-2 space-y-0.5">
      <p v-if="contact.email" class="text-xs text-n-slate-11 truncate flex items-center gap-1">
        <span class="i-lucide-mail w-3 h-3 flex-shrink-0" />
        {{ contact.email }}
      </p>
      <p v-if="contact.phone_number" class="text-xs text-n-slate-11 truncate flex items-center gap-1">
        <span class="i-lucide-phone w-3 h-3 flex-shrink-0" />
        {{ contact.phone_number }}
      </p>
    </div>

    <!-- Deal metadata -->
    <div v-if="deal.title || formattedValue" class="mt-2 pt-2 border-t border-n-weak">
      <p v-if="deal.title" class="text-xs text-n-slate-11 truncate">
        {{ deal.title }}
      </p>
      <p v-if="formattedValue" class="text-xs font-semibold text-green-600 dark:text-green-400">
        {{ formattedValue }}
      </p>
    </div>
  </div>
</template>
