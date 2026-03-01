const express = require('express')
const TaskList = require('../models/TaskList')
const Task     = require('../models/Task')
const requireAuth = require('../middleware/auth')
const { triggerUserEvent } = require('../lib/pusher')

const router = express.Router()
router.use(requireAuth)

// GET /api/lists
router.get('/', async (req, res) => {
  const lists = await TaskList.find({ userId: req.userId }).sort({ createdAt: 1 })
  res.json(lists)
})

// POST /api/lists
router.post('/', async (req, res) => {
  const { name, isDefault = false } = req.body
  if (!name?.trim()) return res.status(400).json({ error: 'name is required' })

  // If this is being set as default, unset any existing default
  if (isDefault) {
    await TaskList.updateMany({ userId: req.userId, isDefault: true }, { $set: { isDefault: false } })
  }

  const list = await TaskList.create({ userId: req.userId, name: name.trim(), isDefault })
  await triggerUserEvent(req.userId, 'list:created', list)
  res.status(201).json(list)
})

// PUT /api/lists/:id
router.put('/:id', async (req, res) => {
  const { name, isDefault } = req.body
  const update = {}
  if (name !== undefined) {
    if (!name.trim()) return res.status(400).json({ error: 'name cannot be empty' })
    update.name = name.trim()
  }
  if (isDefault !== undefined) {
    if (isDefault) {
      await TaskList.updateMany({ userId: req.userId, isDefault: true }, { $set: { isDefault: false } })
    }
    update.isDefault = isDefault
  }

  const list = await TaskList.findOneAndUpdate(
    { _id: req.params.id, userId: req.userId },
    { $set: update },
    { new: true }
  )
  if (!list) return res.status(404).json({ error: 'List not found' })

  await triggerUserEvent(req.userId, 'list:updated', list)
  res.json(list)
})

// DELETE /api/lists/:id
router.delete('/:id', async (req, res) => {
  const list = await TaskList.findOneAndDelete({ _id: req.params.id, userId: req.userId })
  if (!list) return res.status(404).json({ error: 'List not found' })

  await Task.deleteMany({ listId: req.params.id, userId: req.userId })

  await triggerUserEvent(req.userId, 'list:deleted', { _id: req.params.id })
  res.json({ success: true })
})

// GET /api/lists/:id/tasks
router.get('/:id/tasks', async (req, res) => {
  const list = await TaskList.findOne({ _id: req.params.id, userId: req.userId })
  if (!list) return res.status(404).json({ error: 'List not found' })

  const tasks = await Task.find({ listId: req.params.id, userId: req.userId }).sort({ order: 1 })
  res.json(tasks)
})

// POST /api/lists/:id/tasks
router.post('/:id/tasks', async (req, res) => {
  const list = await TaskList.findOne({ _id: req.params.id, userId: req.userId })
  if (!list) return res.status(404).json({ error: 'List not found' })

  const { content } = req.body
  if (!content?.trim()) return res.status(400).json({ error: 'content is required' })

  // Append after last task
  const lastTask = await Task.findOne({ listId: req.params.id }).sort({ order: -1 })
  const order = lastTask ? lastTask.order + 1 : 0

  const now = new Date()
  const task = await Task.create({
    listId:    req.params.id,
    userId:    req.userId,
    content:   content.trim(),
    completed: false,
    order,
    createdAt: now,
    updatedAt: now
  })

  await triggerUserEvent(req.userId, 'task:created', task)
  res.status(201).json(task)
})

module.exports = router
