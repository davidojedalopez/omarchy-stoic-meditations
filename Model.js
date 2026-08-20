.pragma library

var DAY_MS = 24 * 60 * 60 * 1000
var EPOCH_ORDINAL = Math.floor(Date.UTC(2026, 0, 1) / DAY_MS)

function positiveModulo(value, divisor) {
  if (divisor <= 0) return 0
  return ((value % divisor) + divisor) % divisor
}

function utcOrdinalForLocalDate(date) {
  return Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / DAY_MS)
}

function shiftedLocalDate(date, dayOffset) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + Number(dayOffset || 0))
}

function entryById(corpus, id) {
  if (!corpus || !(corpus.entries instanceof Array)) return null
  for (var i = 0; i < corpus.entries.length; i++)
    if (corpus.entries[i].id === id) return corpus.entries[i]
  return null
}

function sourceById(corpus, id) {
  if (!corpus || !(corpus.sources instanceof Array)) return null
  for (var i = 0; i < corpus.sources.length; i++)
    if (corpus.sources[i].id === id) return corpus.sources[i]
  return null
}

function selectEntry(corpus, date, dayOffset) {
  var schedule = corpus && corpus.schedule instanceof Array ? corpus.schedule : []
  if (schedule.length === 0) return null
  var ordinal = utcOrdinalForLocalDate(date) + Number(dayOffset || 0)
  var index = positiveModulo(ordinal - EPOCH_ORDINAL, schedule.length)
  return entryById(corpus, schedule[index])
}
