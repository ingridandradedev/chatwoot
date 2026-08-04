<script setup>
import Draggable from 'vuedraggable';
import DealCard from './DealCard.vue';

const props = defineProps({
  stage: {
    type: Object,
    required: true,
  },
  deals: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['deal-moved', 'deal-click']);

const onDragChange = evt => {
  // When a card is added to this column from another column
  if (evt.added) {
    const deal = evt.added.element;
    const fromStageId = deal.stage_id;
    const toStageId = props.stage.id;
    if (fromStageId !== toStageId) {
      emit('deal-moved', {
        dealId: deal.id,
        fromStageId,
        toStageId,
      });
    }
  }
};

const onCardClick = deal => {
  emit('deal-click', deal);
};
</script>

<template>
  <div class="kanban-column flex flex-col w-72 min-w-[288px] flex-shrink-0 bg-n-alpha-black2 rounded-lg">
    <header class="px-3 py-2 font-medium text-sm border-b text-n-slate-12">
      {{ stage.name }} ({{ deals.length }})
    </header>
    <Draggable
      :list="deals"
      group="deals"
      item-key="id"
      :data-stage-id="stage.id"
      animation="200"
      ghost-class="ghost"
      class="flex-1 p-2 space-y-2 overflow-y-auto min-h-[100px]"
      @change="onDragChange"
    >
      <template #item="{ element }">
        <div @click="onCardClick(element)">
          <DealCard :deal="element" />
        </div>
      </template>
    </Draggable>
  </div>
</template>

<style scoped>
.ghost {
  opacity: 0.5;
}
</style>
