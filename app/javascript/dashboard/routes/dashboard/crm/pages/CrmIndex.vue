<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmPipelinesStore } from 'dashboard/stores/crm/pipelines';
import { useCrmDealsStore } from 'dashboard/stores/crm/deals';
import KanbanColumn from 'dashboard/components/crm/KanbanColumn.vue';

const { t } = useI18n();

const pipelineStore = useCrmPipelinesStore();
const dealStore = useCrmDealsStore();

const selectedPipelineId = ref(null);
const showDealForm = ref(false);

const pipelines = computed(() => pipelineStore.getRecords);
const isFetchingPipelines = computed(
  () => pipelineStore.getUIFlags.fetchingList
);
const isFetchingDeals = computed(() => dealStore.getUIFlags.fetchingList);

const selectedPipeline = computed(() =>
  pipelines.value.find(p => p.id === selectedPipelineId.value)
);
const stages = computed(() => selectedPipeline.value?.stages || []);
const hasNoPipelines = computed(
  () => !isFetchingPipelines.value && pipelines.value.length === 0
);

onMounted(async () => {
  await pipelineStore.get();
  if (pipelines.value.length) {
    // Default to the most recently created pipeline (first in getRecords, sorted by id desc)
    selectedPipelineId.value = pipelines.value[0].id;
  }
});

watch(selectedPipelineId, async id => {
  if (id) {
    await dealStore.fetchForPipeline(id);
  }
});

const onPipelineChange = event => {
  selectedPipelineId.value = Number(event.target.value);
};

const onDealMoved = ({ dealId, fromStageId, toStageId }) => {
  dealStore.moveToStage(
    selectedPipelineId.value,
    dealId,
    fromStageId,
    toStageId
  );
};

const openDealForm = () => {
  showDealForm.value = true;
};

const closeDealForm = () => {
  showDealForm.value = false;
};
</script>

<template>
  <div class="crm-kanban-page flex flex-col h-full bg-n-surface-1">
    <!-- Loading state -->
    <div
      v-if="isFetchingPipelines"
      class="flex items-center justify-center flex-1"
    >
      <span class="text-n-slate-11">
        {{ t('CRM.LOADING') }}
      </span>
    </div>

    <!-- Empty state: no pipelines -->
    <div
      v-else-if="hasNoPipelines"
      class="flex flex-col items-center justify-center flex-1 gap-4"
    >
      <h2 class="text-xl font-medium text-n-slate-12">
        {{ t('CRM.KANBAN.EMPTY_STATE.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-11">
        {{ t('CRM.KANBAN.EMPTY_STATE.DESCRIPTION') }}
      </p>
      <router-link
        :to="{ name: 'crm_pipeline_settings' }"
        class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand"
      >
        {{ t('CRM.KANBAN.EMPTY_STATE.CREATE_PIPELINE') }}
      </router-link>
    </div>

    <!-- Kanban board -->
    <template v-else>
      <!-- Header with pipeline selector -->
      <header
        class="flex items-center justify-between gap-3 px-6 py-4 border-b border-n-strong"
      >
        <div class="flex items-center gap-3">
          <label
            for="pipeline-selector"
            class="text-sm font-medium text-n-slate-11"
          >
            {{ t('CRM.KANBAN.PIPELINE_LABEL') }}
          </label>
          <select
            id="pipeline-selector"
            :value="selectedPipelineId"
            class="px-3 py-1.5 text-sm border rounded-lg border-n-weak bg-n-surface-2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            @change="onPipelineChange"
          >
            <option
              v-for="pipeline in pipelines"
              :key="pipeline.id"
              :value="pipeline.id"
            >
              {{ pipeline.name }}
            </option>
          </select>
        </div>

        <button
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand hover:bg-n-brand-dark"
          @click="openDealForm"
        >
          {{ t('CRM.KANBAN.NEW_DEAL') }}
        </button>
      </header>

      <!-- Board columns -->
      <div
        v-if="isFetchingDeals"
        class="flex items-center justify-center flex-1"
      >
        <span class="text-n-slate-11">
          {{ t('CRM.LOADING') }}
        </span>
      </div>
      <div v-else class="flex flex-1 gap-4 p-4 overflow-x-auto">
        <KanbanColumn
          v-for="stage in stages"
          :key="stage.id"
          :stage="stage"
          :deals="dealStore.getDealsForStage(stage.id)"
          @deal-moved="onDealMoved"
        />
      </div>
    </template>

    <!-- Deal Form Modal placeholder - will be created in task 12.3 -->
    <!-- <DealFormModal
      v-if="showDealForm"
      :pipeline-id="selectedPipelineId"
      :stages="stages"
      @close="closeDealForm"
    /> -->
  </div>
</template>
