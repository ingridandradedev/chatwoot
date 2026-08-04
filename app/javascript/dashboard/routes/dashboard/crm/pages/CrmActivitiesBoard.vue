<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import TaskAPI from 'dashboard/api/crm/tasks';
import ContactAPI from 'dashboard/api/contacts';
import AgentsAPI from 'dashboard/api/agents';
import Draggable from 'vuedraggable';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CalendarView from 'dashboard/components/crm/CalendarView.vue';

const { t } = useI18n();

// View mode toggle
const viewMode = ref('kanban'); // 'kanban' | 'calendar'

const STATUS_COLUMNS = [
  { key: 'pending', label: 'Pendente' },
  { key: 'overdue', label: 'Em Andamento' },
  { key: 'completed', label: 'Concluído' },
];

const tasks = ref([]);
const isLoading = ref(false);
const showCreateModal = ref(false);

// Create form state
const form = ref({
  title: '',
  description: '',
  contactId: null,
  contactName: '',
  assigneeId: null,
  dueDate: '',
  reminderAt: '',
  priority: 'low',
});
const isSubmitting = ref(false);

// Contact search
const contactSearch = ref('');
const contactResults = ref([]);
const isSearchingContacts = ref(false);
const showContactDropdown = ref(false);
let searchTimeout = null;

// Agents
const agents = ref([]);
const isLoadingAgents = ref(false);

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

const isFormValid = computed(() => {
  return !!form.value.title.trim() && !!form.value.contactId && !!form.value.dueDate;
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

const fetchAgents = async () => {
  if (agents.value.length > 0) return;
  isLoadingAgents.value = true;
  try {
    const response = await AgentsAPI.get();
    agents.value = response.data || [];
  } catch {
    agents.value = [];
  } finally {
    isLoadingAgents.value = false;
  }
};

const searchContacts = async query => {
  if (!query || query.length < 2) {
    contactResults.value = [];
    showContactDropdown.value = false;
    return;
  }
  isSearchingContacts.value = true;
  try {
    const response = await ContactAPI.search(query);
    contactResults.value = response.data.payload || response.data || [];
    showContactDropdown.value = contactResults.value.length > 0;
  } catch {
    contactResults.value = [];
    showContactDropdown.value = false;
  } finally {
    isSearchingContacts.value = false;
  }
};

const onContactSearchInput = event => {
  const query = event.target.value;
  contactSearch.value = query;
  if (form.value.contactId && query !== form.value.contactName) {
    form.value.contactId = null;
    form.value.contactName = '';
  }
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => searchContacts(query), 300);
};

const selectContact = contact => {
  form.value.contactId = contact.id;
  form.value.contactName = contact.name || contact.email || `Contact #${contact.id}`;
  contactSearch.value = form.value.contactName;
  showContactDropdown.value = false;
  contactResults.value = [];
};

const openCreateModal = () => {
  resetForm();
  fetchAgents();
  showCreateModal.value = true;
};

const closeCreateModal = () => {
  showCreateModal.value = false;
  formError.value = '';
};

const formError = ref('');

const resetForm = () => {
  form.value = {
    title: '',
    description: '',
    contactId: null,
    contactName: '',
    assigneeId: null,
    dueDate: '',
    reminderAt: '',
    priority: 'low',
  };
  contactSearch.value = '';
  contactResults.value = [];
  showContactDropdown.value = false;
  formError.value = '';
};

const submitTask = async () => {
  if (!isFormValid.value || isSubmitting.value) return;

  // Client-side validation: reminder must be before due date
  if (form.value.reminderAt && form.value.dueDate) {
    const reminder = new Date(form.value.reminderAt);
    const due = new Date(form.value.dueDate);
    if (reminder >= due) {
      formError.value = 'Reminder must be before the due date';
      return;
    }
  }

  formError.value = '';
  isSubmitting.value = true;
  try {
    const payload = {
      title: form.value.title.trim(),
      description: form.value.description.trim() || null,
      assignee_id: form.value.assigneeId ? Number(form.value.assigneeId) : null,
      due_date: form.value.dueDate ? new Date(form.value.dueDate).toISOString() : null,
      reminder_at: form.value.reminderAt ? new Date(form.value.reminderAt).toISOString() : null,
      priority: form.value.priority,
    };

    const { data } = await TaskAPI.createForContact(form.value.contactId, payload);
    const newTask = data.payload || data;
    tasks.value.unshift(newTask);
    closeCreateModal();
  } catch (error) {
    formError.value =
      error?.response?.data?.message ||
      error?.response?.data?.error ||
      'Failed to create task';
    // Error handling - could add toast here
  } finally {
    isSubmitting.value = false;
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

const onTaskDateChanged = async ({ taskId, newDueDate }) => {
  const task = tasks.value.find(t => t.id === taskId);
  if (!task) return;
  const oldDate = task.due_date;
  // Optimistic update
  task.due_date = new Date(newDueDate).getTime() / 1000;
  try {
    await TaskAPI.update(taskId, { due_date: newDueDate });
  } catch {
    task.due_date = oldDate;
  }
};

const formatDueDate = dateStr => {
  if (!dateStr) return '';
  const ts = typeof dateStr === 'number' ? dateStr * 1000 : dateStr;
  const date = new Date(ts);
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
      <div class="flex items-center gap-4">
        <h1 class="text-lg font-semibold text-n-slate-12">
          {{ t('CRM.ACTIVITIES_BOARD.TITLE') }}
        </h1>
        <!-- View mode toggle -->
        <div class="flex items-center rounded-lg border border-n-weak overflow-hidden">
          <button
            class="px-3 py-1.5 text-xs font-medium transition-colors"
            :class="viewMode === 'kanban'
              ? 'bg-n-brand text-white'
              : 'bg-n-surface-2 text-n-slate-11 hover:text-n-slate-12'"
            @click="viewMode = 'kanban'"
          >
            <span class="i-lucide-columns-3 w-3.5 h-3.5 inline-block align-middle mr-1" />
            Kanban
          </button>
          <button
            class="px-3 py-1.5 text-xs font-medium transition-colors border-l border-n-weak"
            :class="viewMode === 'calendar'
              ? 'bg-n-brand text-white'
              : 'bg-n-surface-2 text-n-slate-11 hover:text-n-slate-12'"
            @click="viewMode = 'calendar'"
          >
            <span class="i-lucide-calendar w-3.5 h-3.5 inline-block align-middle mr-1" />
            Calendário
          </button>
        </div>
      </div>
      <NextButton
        label="New Task"
        icon="i-lucide-plus"
        @click="openCreateModal"
      />
    </header>

    <!-- Loading -->
    <div v-if="isLoading" class="flex items-center justify-center py-10 text-n-slate-11">
      <Spinner />
    </div>

    <!-- Calendar view -->
    <CalendarView
      v-else-if="viewMode === 'calendar'"
      :tasks="tasks"
      @task-date-changed="onTaskDateChanged"
    />

    <!-- Kanban columns -->
    <div v-else-if="viewMode === 'kanban'" class="flex flex-1 gap-4 p-4 overflow-x-auto overflow-y-hidden">
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

    <!-- Create Task Modal -->
    <woot-modal :show="showCreateModal" :on-close="closeCreateModal">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header header-title="New Task" />

        <form class="flex flex-col w-full gap-4 px-6 pb-6" @submit.prevent="submitTask">
          <!-- Error message -->
          <div
            v-if="formError"
            class="px-3 py-2 text-sm text-n-ruby-11 bg-n-ruby-3 border border-n-ruby-6 rounded-lg"
          >
            {{ formError }}
          </div>

          <!-- Title -->
          <div class="w-full">
            <label class="block mb-1 text-sm font-medium text-n-slate-12">
              Title <span class="text-n-ruby-9">*</span>
            </label>
            <input
              v-model="form.title"
              type="text"
              class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
              placeholder="Task title"
            />
          </div>

          <!-- Contact search -->
          <div class="relative w-full">
            <label class="block mb-1 text-sm font-medium text-n-slate-12">
              Contact <span class="text-n-ruby-9">*</span>
            </label>
            <input
              :value="contactSearch"
              type="text"
              class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
              placeholder="Search contacts..."
              @input="onContactSearchInput"
              @focus="showContactDropdown = contactResults.length > 0 && !form.contactId"
              @blur="setTimeout(() => { showContactDropdown = false }, 200)"
            />
            <div v-if="isSearchingContacts" class="absolute text-xs right-3 top-9 text-n-slate-10">
              ...
            </div>
            <ul
              v-if="showContactDropdown"
              class="absolute z-10 w-full mt-1 overflow-y-auto bg-white border rounded-lg shadow-lg dark:bg-n-solid-2 border-n-weak max-h-48"
            >
              <li
                v-for="contact in contactResults"
                :key="contact.id"
                class="px-3 py-2 text-sm cursor-pointer text-n-slate-12 hover:bg-n-alpha-2"
                @mousedown.prevent="selectContact(contact)"
              >
                <span class="font-medium">{{ contact.name || 'Unnamed' }}</span>
                <span v-if="contact.email" class="ml-2 text-n-slate-10">{{ contact.email }}</span>
              </li>
            </ul>
          </div>

          <!-- Description -->
          <div class="w-full">
            <label class="block mb-1 text-sm font-medium text-n-slate-12">Description</label>
            <textarea
              v-model="form.description"
              rows="3"
              class="w-full px-3 py-2 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand resize-none"
              placeholder="Optional description"
            />
          </div>

          <!-- Assignee -->
          <div class="w-full">
            <label class="block mb-1 text-sm font-medium text-n-slate-12">Assignee</label>
            <select
              v-model="form.assigneeId"
              class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            >
              <option :value="null">Unassigned</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name || agent.email }}
              </option>
            </select>
          </div>

          <!-- Due Date -->
          <div class="w-full">
            <label class="block mb-1 text-sm font-medium text-n-slate-12">
              Due Date <span class="text-n-ruby-9">*</span>
            </label>
            <input
              v-model="form.dueDate"
              type="datetime-local"
              class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            />
          </div>

          <!-- Reminder -->
          <div class="w-full">
            <label class="block mb-1 text-sm font-medium text-n-slate-12">Reminder</label>
            <input
              v-model="form.reminderAt"
              type="datetime-local"
              class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            />
          </div>

          <!-- Priority -->
          <div class="w-full">
            <label class="block mb-1 text-sm font-medium text-n-slate-12">Priority</label>
            <select
              v-model="form.priority"
              class="w-full h-10 px-3 text-sm border rounded-lg bg-n-alpha-black2 border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            >
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
            </select>
          </div>

          <!-- Actions -->
          <div class="flex flex-row justify-end w-full gap-2 py-2">
            <NextButton
              faded
              slate
              type="reset"
              label="Cancel"
              @click.prevent="closeCreateModal"
            />
            <NextButton
              type="submit"
              label="Create Task"
              :disabled="!isFormValid || isSubmitting"
            />
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>
