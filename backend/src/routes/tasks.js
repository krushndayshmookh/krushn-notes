const express = require('express')
const Task = require('../models/Task')
const requireAuth = require('../middleware/auth')
const { triggerUserEvent } = require('../lib/pusher')

const router = express.Router()
router.use(requireAuth)

// PUT /api/tasks/:id
router.put('/:id', async (req, res) => {
  const { content, completed, order } = req.body
  const update = { updatedAt: new Date() }

  if (content !== undefined) {
    if (!content.trim()) return res.status(400).json({ error: 'content cannot be empty' })
    update.content = content.trim()
  }
  if (completed !== undefined) update.completed = completed
  if (order !== undefined) update.order = order

  const task = await Task.findOneAndUpdate(
    { _id: req.params.id, userId: req.userId },
    { $set: update },
    { new: true }
  )
  if (!task) return res.status(404).json({ error: 'Task not found' })

  await triggerUserEvent(req.userId, 'task:updated', task)
  res.json(task)
})

// DELETE /api/tasks/:id
router.delete('/:id', async (req, res) => {
  const task = await Task.findOneAndDelete({ _id: req.params.id, userId: req.userId })
  if (!task) return res.status(404).json({ error: 'Task not found' })

  await triggerUserEvent(req.userId, 'task:deleted', { _id: req.params.id })
  res.json({ success: true })
})

module.exports = router
