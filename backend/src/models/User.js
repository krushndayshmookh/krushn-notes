const mongoose = require('mongoose')

const userSchema = new mongoose.Schema({
  githubId:  { type: String, required: true, unique: true },
  username:  { type: String, required: true },
  email:     { type: String },
  avatarUrl: { type: String },
  createdAt: { type: Date, default: Date.now }
})

module.exports = mongoose.model('User', userSchema)
