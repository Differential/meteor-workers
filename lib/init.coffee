# The purpose of this module is to:
# - Fork off worker processes, running the same meteor app as master
#   but do not handle any incoming requests.
# - Start polling for new jobs in the worker processes.

cluster = Npm.require "cluster"
os = Npm.require "os"


Meteor.startup ->

  #
  # MASTER PROCESS
  # - Fork off children
  #
  if cluster.isMaster

    unless Meteor.settings?.workers?.disable
      Workers.start()
    else
      Workers.log "Workers disabled."


  #
  # WORKER PROCESS
  # - Extend worker version of Job class and start polling
  #
  if cluster.isWorker

    if process.env.WORKERS_SCHEDULER
      Scheduler.init()
      Scheduler.start()
    else
      Worker.init()
      Worker.start()
