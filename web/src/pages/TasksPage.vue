<template>
  <q-page class="column" style="height: calc(100vh - 50px); overflow: hidden;">
    <!-- List header -->
    <div class="row items-center q-px-lg q-py-md" style="border-bottom: 1px solid rgba(0,0,0,0.08);">
      <div class="text-h6 text-weight-bold col">
        {{ activeList?.name || 'Tasks' }}
      </div>
      <q-btn flat round icon="edit" size="sm" @click="startRenameList" v-if="activeList" />
      <q-btn flat round icon="delete_outline" size="sm" color="negative" @click="confirmDeleteList" v-if="activeList" />
    </div>

    <!-- No list selected -->
    <div v-if="!tasksStore.activeListId" class="col column items-center justify-center text-grey">
      <q-icon name="checklist" size="64px" />
      <div class="q-mt-md text-subtitle1">Select or create a task list</div>
    </div>

    <template v-else>
      <!-- Task list -->
      <q-scroll-area class="col q-px-lg q-pt-md">
        <q-list>
          <q-item
            v-for="task in tasksStore.tasks"
            :key="task._id"
            dense class="q-px-none"
          >
            <q-item-section avatar style="min-width: 32px;">
              <q-checkbox
                :model-value="task.completed"
                @update:model-value="tasksStore.toggleTask(task._id)"
                dense
              />
            </q-item-section>
            <q-item-section>
              <q-input
                :model-value="task.content"
                borderless dense
                :class="{ 'text-strike text-grey': task.completed }"
                style="font-size: 15px;"
                @update:model-value="(val) => updateContent(task._id, val)"
                @blur="flushUpdate(task._id)"
              />
            </q-item-section>
            <q-item-section side>
              <q-btn
                flat round icon="close" size="xs" color="grey"
                @click="tasksStore.deleteTask(task._id)"
              />
            </q-item-section>
          </q-item>
        </q-list>

        <!-- Empty state -->
        <div v-if="!tasksStore.tasks.length" class="text-grey text-caption q-py-md text-center">
          No tasks yet — add one below
        </div>
      </q-scroll-area>

      <!-- Add task input -->
      <div class="q-px-lg q-py-md" style="border-top: 1px solid rgba(0,0,0,0.08);">
        <q-input
          v-model="newTaskContent"
          placeholder="Add a task…"
          dense outlined
          @keyup.enter="addTask"
        >
          <template #append>
            <q-btn flat round icon="add" size="sm" @click="addTask" />
          </template>
        </q-input>
      </div>
    </template>

    <!-- Rename List dialog -->
    <q-dialog v-model="showRenameList" @hide="renameListValue = ''">
      <q-card style="min-width: 300px;" flat bordered>
        <q-card-section class="text-h6">Rename List</q-card-section>
        <q-card-section>
          <q-input v-model="renameListValue" autofocus dense outlined @keyup.enter="doRenameList" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat label="Save" color="primary" @click="doRenameList" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useTasksStore } from '../stores/tasks'

const route  = useRoute()
const router = useRouter()
const $q     = useQuasar()
const tasksStore = useTasksStore()

const activeList     = computed(() => tasksStore.taskLists.find(l => l._id === tasksStore.activeListId))
const newTaskContent = ref('')
const showRenameList = ref(false)
const renameListValue = ref('')

// Pending content edits (debounced)
const pendingUpdates = {}
const updateTimers   = {}

onMounted(async () => {
  if (route.params.listId) {
    await tasksStore.selectList(route.params.listId)
  } else if (!tasksStore.activeListId && tasksStore.taskLists.length) {
    const def = tasksStore.defaultList
    if (def) {
      await tasksStore.selectList(def._id)
      router.replace(`/tasks/${def._id}`)
    }
  }
})

async function addTask() {
  if (!newTaskContent.value.trim()) return
  await tasksStore.addTask(newTaskContent.value.trim())
  newTaskContent.value = ''
}

function updateContent(id, val) {
  pendingUpdates[id] = val
  clearTimeout(updateTimers[id])
  updateTimers[id] = setTimeout(() => flushUpdate(id), 800)
}

async function flushUpdate(id) {
  clearTimeout(updateTimers[id])
  if (pendingUpdates[id] !== undefined) {
    await tasksStore.updateTaskContent(id, pendingUpdates[id])
    delete pendingUpdates[id]
  }
}

function startRenameList() {
  renameListValue.value = activeList.value?.name || ''
  showRenameList.value  = true
}

async function doRenameList() {
  if (!renameListValue.value.trim()) return
  await tasksStore.renameList(tasksStore.activeListId, renameListValue.value.trim())
  showRenameList.value = false
}

function confirmDeleteList() {
  $q.dialog({
    title: 'Delete list?',
    message: 'All tasks will be deleted. This cannot be undone.',
    cancel: true,
    persistent: true
  }).onOk(async () => {
    await tasksStore.deleteList(tasksStore.activeListId)
    router.push('/tasks')
  })
}
</script>
