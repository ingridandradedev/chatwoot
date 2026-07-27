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

const emit = defineEmits(['deal-moved']);

const onDragEnd = evt => {
  if (evt.to !== evt.from || evt.oldIndex !== evt.newIndex) {
    const dealId = Number(evt.item.dataset.dealId);
    const toStageId = Number(evt.to.dataset.stageId);
    const fromStageId = props.stage.id;
    if (fromStageId !== toStageId) {
      emit('deal-moved', { dealId, fromStageId, toStageId });
    }
  }
};
</script>

<template>
  <div class="kanban-column flex flex-col w-72 min-w-[288px] bg-n-alpha-black2 rounded-lg">
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
      class="flex-1 p-2 space-y-2 overflow-y-auto"
      @end="onDragEnd"
    >
      <template #item="{ element }">
        <DealCard :deal="element" />
      </template>
    </Draggable>
  </div>
</template>

<style scoped>
.ghost {
  opacity: 0.5;
}
</style>
