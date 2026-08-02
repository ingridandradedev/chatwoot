<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import TaskAPI from 'dashboard/api/crm/tasks';
import Draggable from 'vuedraggable';

const { t } = useI18n();

const STATUS_COLUMNS = [
  { key: 'pending', label: 'Pendente' },
  { key: 'overdue', label: 'Em Andamento' },
  { key: 'completed', label: 'Concluído' },
];

const tasks = ref([]);
const isLoading = ref(false);

const tasksByStatus = computed(() => {
  const grouped = { pending: [], overdue: [], completed: [] };
  tasks.value.forEach(task => {
    const status = task.status || 'pending';
    if (grouped[status]) {
      grouped[status].push(task);
    } else {
      grouped.pending.push(task);
    }
  });
  return grouped;
});

const fetchTasks = async () => {
  isLoading.value = true;
  try {
    const { data } = await TaskAPI.getAll();
    tasks.value = data.payload || data || [];
  } catch {
    tasks.value = [];
  } finally {
    isLoading.value = false;
  }
};

const onDragEnd = async (evt, toStatus) => {
  const taskId = Number(evt.item.dataset.taskId);
  if (!taskId) return;

  const task = tasks.value.find(t => t.id === taskId);
  if (!task || task.status === toStatus) return;

  const oldStatus = task.status;
  task.status = toStatus;

  try {
    if (toStatus === 'completed') {
      await TaskAPI.complete(taskId);
    } else if (oldStatus === 'completed' && toStatus === 'pending') {
      await TaskAPI.reopen(taskId);
    } else {
      await TaskAPI.update(taskId, { status: toStatus });
    }
  } catch {
    task.status = oldStatus;
  }
};

const formatDueDate = dateStr => {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
};

const priorityClass = priority => {
  const map = {
    high: 'bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300',
    medium: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900 dark:text-yellow-300',
    low: 'bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300',
  };
  return map[priority] || map.low;
};

onMounted(fetchTasks);
</script>

<template>
  <div class="flex flex-col h-full bg-n-surface-1">
    <!-- Header -->
    <header class="flex items-center justify-between px-6 py-4 border-b border-n-strong">
      <h1 class="text-lg font-semibold text-n-slate-12">
        {{ t('CRM.ACTIVITIES_BOARD.TITLE') }}
      </h1>
    </header>

    <!-- Loading -->
    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <span class="text-n-slate-11">{{ t('CRM.LOADING') }}</span>
    </div>

    <!-- Kanban columns -->
    <div v-else class="flex flex-1 gap-4 p-4 overflow-x-auto">
      <div
        v-for="column in STATUS_COLUMNS"
        :key="column.key"
        class="flex flex-col w-80 min-w-[320px] bg-n-alpha-black2 rounded-lg"
      >
        <!-- Column header -->
        <header class="px-3 py-2 font-medium text-sm border-b text-n-slate-12 flex items-center justify-between">
          <span>{{ column.label }}</span>
          <span class="text-xs text-n-slate-10 bg-n-surface-3 px-2 py-0.5 rounded-full">
            {{ tasksByStatus[column.key].length }}
          </span>
        </header>

        <!-- Draggable task list -->
        <Draggable
          :list="tasksByStatus[column.key]"
          group="activities"
          item-key="id"
          animation="200"
          ghost-class="opacity-50"
          class="flex-1 p-2 space-y-2 overflow-y-auto"
          @end="evt => onDragEnd(evt, column.key)"
        >
          <template #item="{ element: task }">
            <div
              :data-task-id="task.id"
              class="p-3 bg-white dark:bg-n-slate-3 rounded-lg shadow-sm border border-n-weak cursor-grab"
              :class="{ 'border-red-300 dark:border-red-700': task.status === 'overdue' }"
            >
              <p class="text-sm font-medium text-n-slate-12 truncate">
                {{ task.title }}
              </p>
              <div class="flex items-center gap-2 mt-2">
                <span
                  class="px-1.5 py-0.5 text-xs font-medium rounded"
                  :class="priorityClass(task.priority)"
                >
                  {{ task.priority }}
                </span>
                <span v-if="task.due_date" class="text-xs text-n-slate-10">
                  {{ formatDueDate(task.due_date) }}
                </span>
              </div>
              <p v-if="task.assignee" class="text-xs text-n-slate-10 mt-1">
                {{ task.assignee.name || task.assignee_name }}
              </p>
              <p v-if="task.contact" class="text-xs text-n-slate-11 mt-1">
                → {{ task.contact.name || task.contact_name }}
              </p>
            </div>
          </template>
        </Draggable>
      </div>
    </div>
  </div>
</template>
