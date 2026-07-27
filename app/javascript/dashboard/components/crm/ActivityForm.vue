<script setup>
import { ref, computed } from 'vue';
import { useCrmActivitiesStore } from 'dashboard/stores/crm/activities';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['created']);

const store = useCrmActivitiesStore();

const MANUAL_ACTIVITY_TYPES = [
  { value: 'call', label: 'Call' },
  { value: 'email', label: 'Email' },
  { value: 'meeting', label: 'Meeting' },
  { value: 'note', label: 'Note' },
];

const activityType = ref('');
const description = ref('');

const isCreating = computed(() => store.getUIFlags.creatingItem);
const isValid = computed(
  () => activityType.value.length > 0 && description.value.trim().length > 0
);

const resetForm = () => {
  activityType.value = '';
  description.value = '';
};

const handleSubmit = async () => {
  if (!isValid.value || isCreating.value) return;

  const result = await store.createForContact(props.contactId, {
    activity_type: activityType.value,
    description: description.value.trim(),
  });

  if (result && result.id) {
    resetForm();
    emit('created', result);
  }
};
</script>

<template>
  <form
    class="activity-form flex flex-col gap-3 p-4 bg-white dark:bg-n-slate-3 rounded-lg border border-n-weak"
    @submit.prevent="handleSubmit"
  >
    <!-- Type selector -->
    <div class="flex flex-col gap-1">
      <label
        for="activity-type"
        class="text-xs font-medium text-n-slate-11"
      >
        Type
      </label>
      <select
        id="activity-type"
        v-model="activityType"
        class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-white dark:bg-n-slate-2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-woot-500"
      >
        <option value="" disabled>Select type...</option>
        <option
          v-for="type in MANUAL_ACTIVITY_TYPES"
          :key="type.value"
          :value="type.value"
        >
          {{ type.label }}
        </option>
      </select>
    </div>

    <!-- Description textarea -->
    <div class="flex flex-col gap-1">
      <label
        for="activity-description"
        class="text-xs font-medium text-n-slate-11"
      >
        Description
      </label>
      <textarea
        id="activity-description"
        v-model="description"
        rows="3"
        placeholder="Describe the activity..."
        class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-white dark:bg-n-slate-2 text-n-slate-12 resize-y focus:outline-none focus:ring-2 focus:ring-woot-500"
      />
    </div>

    <!-- Submit button -->
    <div class="flex justify-end">
      <button
        type="submit"
        class="px-4 py-2 text-sm font-medium text-white bg-woot-500 rounded-lg hover:bg-woot-600 disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="!isValid || isCreating"
      >
        {{ isCreating ? 'Saving...' : 'Add Activity' }}
      </button>
    </div>
  </form>
</template>
