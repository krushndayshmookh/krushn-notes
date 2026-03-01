const mongoose = require('mongoose')

const taskSchema = new mongoose.Schema({
  listId:    { type: mongoose.Schema.Types.ObjectId, ref: 'TaskList', required: true, index: true },
  userId:    { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  content:   { type: String, required: true },
  completed: { type: Boolean, default: false },
  order:     { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
})

taskSchema.index({ listId: 1, order: 1 })

module.exports = mongoose.model('Task', taskSchema)
