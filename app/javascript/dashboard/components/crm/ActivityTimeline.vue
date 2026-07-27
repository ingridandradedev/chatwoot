<script setup>
import { computed, onMounted } from 'vue';
import { useCrmActivitiesStore } from 'dashboard/stores/crm/activities';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const store = useCrmActivitiesStore();

const activities = computed(() => store.getActivities);
const meta = computed(() => store.getMeta);
const isFetching = computed(() => store.getUIFlags.fetchingList);
const hasMore = computed(() => meta.value.page < meta.value.totalPages);

const ACTIVITY_TYPE_CONFIG = {
  call: { label: 'Call', color: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' },
  email: { label: 'Email', color: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' },
  meeting: { label: 'Meeting', color: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200' },
  note: { label: 'Note', color: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200' },
  stage_change: { label: 'Stage Change', color: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200' },
  task_completed: { label: 'Task Completed', color: 'bg-teal-100 text-teal-800 dark:bg-teal-900 dark:text-teal-200' },
};

const getTypeConfig = type => {
  return ACTIVITY_TYPE_CONFIG[type] || { label: type, color: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200' };
};

const formatTimestamp = timestamp => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  return date.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const loadMore = () => {
  if (!isFetching.value && hasMore.value) {
    store.fetchForContact(props.contactId, meta.value.page + 1);
  }
};

onMounted(() => {
  store.fetchForContact(props.contactId, 1);
});
</script>

<template>
  <div class="activity-timeline flex flex-col gap-3">
    <!-- Loading state for initial fetch -->
    <div
      v-if="isFetching && activities.length === 0"
      class="flex items-center justify-center py-8 text-sm text-n-slate-11"
    >
      Loading activities...
    </div>

    <!-- Empty state -->
    <div
      v-else-if="!isFetching && activities.length === 0"
      class="flex items-center justify-center py-8 text-sm text-n-slate-11"
    >
      No activities yet.
    </div>

    <!-- Activity list -->
    <div
      v-for="activity in activities"
      :key="activity.id"
      class="flex gap-3 p-3 bg-white dark:bg-n-slate-3 rounded-lg border border-n-weak"
    >
      <!-- Type badge -->
      <div class="flex-shrink-0 pt-0.5">
        <span
          class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
          :class="getTypeConfig(activity.activity_type).color"
        >
          {{ getTypeConfig(activity.activity_type).label }}
        </span>
      </div>

      <!-- Content -->
      <div class="flex-1 min-w-0">
        <p class="text-sm text-n-slate-12 whitespace-pre-wrap break-words">
          {{ activity.description }}
        </p>
        <div class="flex items-center gap-2 mt-1 text-xs text-n-slate-11">
          <span v-if="activity.user?.name || activity.user_name">
            {{ activity.user?.name || activity.user_name }}
          </span>
          <span v-if="activity.created_at">
            · {{ formatTimestamp(activity.created_at) }}
          </span>
        </div>
      </div>
    </div>

    <!-- Load more button -->
    <div v-if="hasMore" class="flex justify-center pt-2">
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium text-n-slate-12 bg-white dark:bg-n-slate-3 border border-n-weak rounded-lg hover:bg-n-alpha-black2 disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="isFetching"
        @click="loadMore"
      >
        {{ isFetching ? 'Loading...' : 'Load more' }}
      </button>
    </div>
  </div>
</template>
