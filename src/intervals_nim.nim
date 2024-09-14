import std/times
import std/os
import std/strutils
import std/logging

import asciigraph

import intervals_icu
import google_sheet

const fmtStr = "[$date $time] - $levelname: "

proc run(offset: int) =
  let today = (now() + initDuration(days = offset))
  info "Process: ", today.format("yyyy-MM-dd")
  let client = newGSheetClient()
  let row = client.row(today)
  let plan = row.plan
  info "Plan: ", plan
  let activities = activities(today)
  info "Activities:"
  for x in activities:
    info "    ", x.name
    echo plot(x.watts, width = 110, height = 10)
  if activities.len > 0:
    let stat = stats(activities)
    info "Stats: ", stat
    row.distance = activities.distanceSumVal
    row.movingTime = activities.movingTimeVal
    row.calories = activities.caloriesSumVal
    row.virtual = activities.virtualVal
    row.result = activities.resultVal(plan)
  info "Finished"

proc main() =
  createDir "logs"
  addHandler(newConsoleLogger(fmtStr = fmtStr))
  addHandler(newRollingFileLogger("logs/intervals_nim.log", mode = fmAppend, fmtStr = fmtStr))
  try:
    run(if paramCount() == 1: paramStr(1).parseInt else: 0)
  except:
    let e = getCurrentException()
    fatal "name: ", e.name, "    msg: ", e.msg, "\n", e.getStackTrace


when isMainModule:
  main()
