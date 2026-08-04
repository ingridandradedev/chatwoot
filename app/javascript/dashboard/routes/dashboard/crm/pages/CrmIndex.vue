<script setup>
import { ref, computed, onMounted, onActivated, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import PipelineAPI from 'dashboard/api/crm/pipelines';
import DealAPI from 'dashboard/api/crm/deals';
import KanbanColumn from 'dashboard/components/crm/KanbanColumn.vue';
import DealFormModal from 'dashboard/components/crm/DealFormModal.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const router = useRouter();

const pipelines = ref([]);
const selectedPipelineId = ref(null);
const showDealForm = ref(false);
const isFetchingPipelines = ref(false);
const isFetchingDeals = ref(false);

// Local mutable state for deals grouped by stage — vuedraggable can mutate these directly
const dealsByStage = ref({});

const selectedPipeline = computed(() =>
  pipelines.value.find(p => p.id === selectedPipelineId.value)
);
const stages = computed(() => selectedPipeline.value?.stages || []);
const cardFields = computed(() => selectedPipeline.value?.card_fields || ['name', 'email', 'phone_number']);
const hasNoPipelines = computed(
  () => !isFetchingPipelines.value && pipelines.value.length === 0
);

const getDealsForStage = stageId => {
  if (!dealsByStage.value[stageId]) {
    dealsByStage.value[stageId] = [];
  }
  return dealsByStage.value[stageId];
};

const fetchPipelines = async () => {
  isFetchingPipelines.value = true;
  try {
    const { data } = await PipelineAPI.get();
    pipelines.value = data.payload || data || [];
  } catch {
    pipelines.value = [];
  } finally {
    isFetchingPipelines.value = false;
  }
};

const fetchDeals = async pipelineId => {
  isFetchingDeals.value = true;
  try {
    const { data } = await DealAPI.getForPipeline(pipelineId);
    const deals = data.payload || data || [];
    // Group by stage_id into local mutable arrays
    const grouped = {};
    stages.value.forEach(stage => {
      grouped[stage.id] = [];
    });
    deals.forEach(deal => {
      const sid = deal.stage_id;
      if (!grouped[sid]) grouped[sid] = [];
      grouped[sid].push(deal);
    });
    dealsByStage.value = grouped;
  } catch {
    dealsByStage.value = {};
  } finally {
    isFetchingDeals.value = false;
  }
};

onMounted(async () => {
  await fetchPipelines();
  if (pipelines.value.length) {
    selectedPipelineId.value = pipelines.value[0].id;
  }
});

// Also refresh when navigating back to this page (e.g., after changing settings)
onActivated(async () => {
  await fetchPipelines();
});

watch(selectedPipelineId, async id => {
  if (id) {
    await fetchDeals(id);
  }
});

const onPipelineChange = event => {
  selectedPipelineId.value = Number(event.target.value);
};

const onDealMoved = async ({ dealId, fromStageId, toStageId }) => {
  // The vuedraggable already moved the item in the local arrays
  // Now sync with the API
  try {
    await DealAPI.moveToStage(selectedPipelineId.value, dealId, toStageId);
  } catch {
    // Revert: move it back
    const toArray = dealsByStage.value[toStageId] || [];
    const idx = toArray.findIndex(d => d.id === dealId);
    if (idx !== -1) {
      const [deal] = toArray.splice(idx, 1);
      deal.stage_id = fromStageId;
      if (!dealsByStage.value[fromStageId]) dealsByStage.value[fromStageId] = [];
      dealsByStage.value[fromStageId].push(deal);
    }
  }
};

const onDealClick = deal => {
  const accountId = router.currentRoute.value.params.accountId;
  router.push(`/app/accounts/${accountId}/contacts/${deal.contact?.id || deal.contact_id}`);
};

const openDealForm = () => {
  showDealForm.value = true;
};

const closeDealForm = () => {
  showDealForm.value = false;
};

const onDealFormSubmit = async dealData => {
  try {
    const { data } = await DealAPI.create(selectedPipelineId.value, dealData);
    const newDeal = data.payload || data;
    const sid = newDeal.stage_id;
    if (!dealsByStage.value[sid]) dealsByStage.value[sid] = [];
    dealsByStage.value[sid].push(newDeal);
    showDealForm.value = false;
  } catch {
    // handle error
  }
};
</script>

<template>
  <div class="crm-kanban-page flex flex-col h-full bg-n-surface-1">
    <!-- Loading state -->
    <div
      v-if="isFetchingPipelines"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
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
      <!-- Header -->
      <header class="flex items-center justify-between gap-3 px-6 py-4 border-b border-n-strong">
        <div class="flex items-center gap-3">
          <label for="pipeline-selector" class="text-sm font-medium text-n-slate-11">
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
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>
      <div v-else class="flex flex-1 gap-4 p-4 overflow-x-auto overflow-y-hidden">
        <KanbanColumn
          v-for="stage in stages"
          :key="stage.id"
          :stage="stage"
          :deals="getDealsForStage(stage.id)"
          :card-fields="cardFields"
          @deal-moved="onDealMoved"
          @deal-click="onDealClick"
        />
      </div>
    </template>

    <!-- Deal Form Modal -->
    <DealFormModal
      :show="showDealForm"
      :pipeline-id="selectedPipelineId"
      :stages="stages"
      @submit="onDealFormSubmit"
      @close="closeDealForm"
    />
  </div>
</template>
