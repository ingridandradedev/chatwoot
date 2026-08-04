<script setup>
import { ref, computed } from 'vue';
import TaskAPI from 'dashboard/api/crm/tasks';

const props = defineProps({
  tasks: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['task-date-changed', 'task-click']);

const today = new Date();
const currentMonth = ref(today.getMonth());
const currentYear = ref(today.getFullYear());

const WEEKDAYS = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

const monthLabel = computed(() => {
  const date = new Date(currentYear.value, currentMonth.value, 1);
  return date.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
});

const calendarDays = computed(() => {
  const year = currentYear.value;
  const month = currentMonth.value;

  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const startDayOfWeek = firstDay.getDay();
  const totalDays = lastDay.getDate();

  const days = [];

  // Pad with empty slots for days before the 1st
  for (let i = 0; i < startDayOfWeek; i++) {
    days.push({ day: null, date: null });
  }

  // Actual days of the month
  for (let d = 1; d <= totalDays; d++) {
    const date = new Date(year, month, d);
    days.push({ day: d, date });
  }

  return days;
});

const getTasksForDay = day => {
  if (!day) return [];
  const dayStart = new Date(currentYear.value, currentMonth.value, day);
  const dayEnd = new Date(currentYear.value, currentMonth.value, day + 1);

  return props.tasks.filter(task => {
    if (!task.due_date) return false;
    const ts = typeof task.due_date === 'number' ? task.due_date * 1000 : task.due_date;
    const taskDate = new Date(ts);
    return taskDate >= dayStart && taskDate < dayEnd;
  });
};

const isToday = day => {
  if (!day) return false;
  return (
    day === today.getDate() &&
    currentMonth.value === today.getMonth() &&
    currentYear.value === today.getFullYear()
  );
};

const prevMonth = () => {
  if (currentMonth.value === 0) {
    currentMonth.value = 11;
    currentYear.value--;
  } else {
    currentMonth.value--;
  }
};

const nextMonth = () => {
  if (currentMonth.value === 11) {
    currentMonth.value = 0;
    currentYear.value++;
  } else {
    currentMonth.value++;
  }
};

const goToToday = () => {
  currentMonth.value = today.getMonth();
  currentYear.value = today.getFullYear();
};

const priorityDot = priority => {
  const map = {
    high: 'bg-red-500',
    medium: 'bg-yellow-500',
    low: 'bg-green-500',
  };
  return map[priority] || 'bg-n-slate-8';
};

const statusBg = status => {
  const map = {
    completed: 'opacity-50 line-through',
    overdue: 'text-red-600 dark:text-red-400',
    pending: '',
  };
  return map[status] || '';
};

// Drag state
const draggedTask = ref(null);

const onDragStart = (event, task) => {
  draggedTask.value = task;
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('text/plain', task.id);
};

const onDragOver = event => {
  event.preventDefault();
  event.dataTransfer.dropEffect = 'move';
};

const onDrop = (event, day) => {
  event.preventDefault();
  if (!draggedTask.value || !day) return;

  const newDate = new Date(currentYear.value, currentMonth.value, day, 12, 0, 0);
  emit('task-date-changed', {
    taskId: draggedTask.value.id,
    newDueDate: newDate.toISOString(),
  });
  draggedTask.value = null;
};
</script>

<template>
  <div class="flex flex-col h-full">
    <!-- Calendar header: navigation -->
    <div class="flex items-center justify-between px-4 py-3 border-b border-n-strong">
      <div class="flex items-center gap-2">
        <button
          class="p-1.5 rounded-md hover:bg-n-alpha-black2 text-n-slate-11"
          @click="prevMonth"
        >
          <span class="i-lucide-chevron-left w-4 h-4" />
        </button>
        <h2 class="text-sm font-semibold text-n-slate-12 capitalize min-w-[160px] text-center">
          {{ monthLabel }}
        </h2>
        <button
          class="p-1.5 rounded-md hover:bg-n-alpha-black2 text-n-slate-11"
          @click="nextMonth"
        >
          <span class="i-lucide-chevron-right w-4 h-4" />
        </button>
      </div>
      <button
        class="px-3 py-1 text-xs font-medium rounded-md border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
        @click="goToToday"
      >
        Hoje
      </button>
    </div>

    <!-- Weekday headers -->
    <div class="grid grid-cols-7 border-b border-n-strong">
      <div
        v-for="weekday in WEEKDAYS"
        :key="weekday"
        class="px-2 py-1.5 text-xs font-medium text-center text-n-slate-10 border-r border-n-weak last:border-r-0"
      >
        {{ weekday }}
      </div>
    </div>

    <!-- Calendar grid -->
    <div class="grid grid-cols-7 flex-1 auto-rows-fr">
      <div
        v-for="(cell, idx) in calendarDays"
        :key="idx"
        class="border-r border-b border-n-weak last:border-r-0 p-1 min-h-[80px] overflow-hidden"
        :class="{
          'bg-n-blue-2 dark:bg-n-blue-1': isToday(cell.day),
          'bg-transparent': !isToday(cell.day),
        }"
        @dragover="onDragOver"
        @drop="e => onDrop(e, cell.day)"
      >
        <!-- Day number -->
        <div v-if="cell.day" class="flex items-center justify-between mb-1">
          <span
            class="text-xs font-medium"
            :class="isToday(cell.day) ? 'text-n-blue-11 font-bold' : 'text-n-slate-11'"
          >
            {{ cell.day }}
          </span>
          <span
            v-if="getTasksForDay(cell.day).length > 0"
            class="text-xxs text-n-slate-9"
          >
            {{ getTasksForDay(cell.day).length }}
          </span>
        </div>

        <!-- Task pills -->
        <div v-if="cell.day" class="space-y-0.5 overflow-y-auto max-h-[60px]">
          <div
            v-for="task in getTasksForDay(cell.day)"
            :key="task.id"
            class="flex items-center gap-1 px-1.5 py-0.5 rounded text-xxs cursor-grab hover:bg-n-alpha-black2 truncate"
            :class="statusBg(task.status)"
            draggable="true"
            @dragstart="e => onDragStart(e, task)"
            @click.stop="$emit('task-click', task)"
          >
            <span class="w-1.5 h-1.5 rounded-full flex-shrink-0" :class="priorityDot(task.priority)" />
            <span class="truncate text-n-slate-12">{{ task.title }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
