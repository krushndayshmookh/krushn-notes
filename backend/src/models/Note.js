const mongoose = require('mongoose')

const noteSchema = new mongoose.Schema({
  userId:    { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  folderId:  { type: mongoose.Schema.Types.ObjectId, ref: 'Folder', default: null, index: true },
  title:     { type: String, default: '' },
  content:   { type: String, default: '' },
  tags:      { type: [String], default: [], index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
})

noteSchema.index({ userId: 1, updatedAt: -1 })

module.exports = mongoose.model('Note', noteSchema)
