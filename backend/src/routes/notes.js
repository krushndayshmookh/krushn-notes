const express = require('express')
const Note = require('../models/Note')
const requireAuth = require('../middleware/auth')
const { triggerUserEvent } = require('../lib/pusher')
const extractTags = require('../lib/extractTags')

const router = express.Router()
router.use(requireAuth)

// GET /api/notes — list notes (metadata only); optional ?folderId= or ?tag=
router.get('/', async (req, res) => {
  const query = { userId: req.userId }

  if (req.query.folderId !== undefined) {
    query.folderId = req.query.folderId || null
  }
  if (req.query.tag) {
    query.tags = req.query.tag.toLowerCase()
  }

  const notes = await Note.find(query)
    .select('title tags folderId updatedAt createdAt')
    .sort({ updatedAt: -1 })

  res.json(notes)
})

// POST /api/notes
router.post('/', async (req, res) => {
  const { title = '', content = '', folderId = null } = req.body
  const tags = extractTags(content)
  const now = new Date()

  const note = await Note.create({
    userId: req.userId,
    title: title.trim(),
    content,
    folderId: folderId || null,
    tags,
    createdAt: now,
    updatedAt: now
  })

  await triggerUserEvent(req.userId, 'note:created', note)
  res.status(201).json(note)
})

// GET /api/notes/:id
router.get('/:id', async (req, res) => {
  const note = await Note.findOne({ _id: req.params.id, userId: req.userId })
  if (!note) return res.status(404).json({ error: 'Note not found' })
  res.json(note)
})

// PUT /api/notes/:id
router.put('/:id', async (req, res) => {
  const { title, content, folderId } = req.body
  const update = { updatedAt: new Date() }

  if (title !== undefined) update.title = title.trim()
  if (content !== undefined) {
    update.content = content
    update.tags = extractTags(content)
  }
  if (folderId !== undefined) update.folderId = folderId || null

  const note = await Note.findOneAndUpdate(
    { _id: req.params.id, userId: req.userId },
    { $set: update },
    { new: true }
  )
  if (!note) return res.status(404).json({ error: 'Note not found' })

  await triggerUserEvent(req.userId, 'note:updated', note)
  res.json(note)
})

// DELETE /api/notes/:id
router.delete('/:id', async (req, res) => {
  const note = await Note.findOneAndDelete({ _id: req.params.id, userId: req.userId })
  if (!note) return res.status(404).json({ error: 'Note not found' })

  await triggerUserEvent(req.userId, 'note:deleted', { _id: req.params.id })
  res.json({ success: true })
})

module.exports = router
