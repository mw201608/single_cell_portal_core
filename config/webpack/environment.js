const { environment } = require('@rails/webpacker')
const typescript =  require('./loaders/typescript')

environment.loaders.delete('nodeModules')

environment.loaders.prepend('typescript', typescript)
module.exports = environment
