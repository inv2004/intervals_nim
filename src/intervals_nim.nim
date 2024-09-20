import std/times
import std/os
import std/strutils
import std/logging
import std/sequtils
import std/tables

import asciigraph

import intervals_icu
import google_sheet
import telegram

const fmtStr = "[$date $time] - $levelname: "

proc run(offset: int) =
  var gclient: GSheetClient

  let bot = newTeleBot()
  let upds = bot.getUpdates()
  if upds.len > 0:
    gclient = newGSheetClient()
    gclient.setUpdates(upds)

  let today = (now() + initDuration(days = offset))
  info "Process: ", today.format("yyyy-MM-dd")

  let activities = activities(today)
  info "Activities:"
  for x in activities:
    info "    ", x.name, "\n" & plot(x.watts, width = 110, height = 10).splitLines().mapIt("W: " & it).join("\n")
  if activities.len > 0:
    if gclient.isNil:
      gclient = newGSheetClient()
    var row = gclient.row(today)
    let plan = row.plan
    info "Plan: ", plan
    info "Stat: ", stat(activities)
    row.distance = activities.distanceSumVal
    row.movingTime = activities.movingTimeVal
    row.calories = activities.caloriesSumVal
    row.virtual = activities.virtualVal
    row.result = activities.resultVal(plan)
    if row.newResult != "":
      bot.sendMsg(row.newResult.replace("bot: ", row.date & ": "))
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
