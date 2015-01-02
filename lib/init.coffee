# The purpose of this module is to:
# - Fork off worker processes, running the same meteor app as master
#   but do not handle any incoming requests.
# - Start polling for new jobs in the worker processes.

cluster = Npm.require "cluster"
os = Npm.require "os"


Meteor.startup ->

  #
  # MASTER PROCESS
  # - Fork off children and extend master version of Job clas
  #
  if cluster.isMaster

    # If server(s) have been restarted, re-queue any dequeued jobs
    # - These are likely jobs that were in the middle of processing
    #   when the process was killed.
    # XXX: Not fully tested, may require more thought
    count = Jobs.update status: "dequeued",
      $set: status: "queued"
    , multi: true
    WorkersUtil.log "Requeued #{count} jobs."


    # All master processes register themselves into a single document collection
    # on startup.  The last one to start up across all deployments
    # will spawn the the scheduler.
    SchedulerHelper.update name: "scheduler",
      $set: hostname: os.hostname()
    , upsert: true


    unless Meteor.settings?.workers?.disable
      # Fork off worker processes
      WorkersUtil.start()
    else
      WorkersUtil.log "Workers disabled."



  #
  # WORKER PROCESS
  # - Extend worker version of Job class and start polling
  #
  if cluster.isWorker

    if process.env.WORKERS_SCHEDULER
      Scheduler.init()
      Scheduler.start()
    else
      Workers.init()
      Workers.start()


    process.on "message", (msg) ->
      WorkersUtil.log msg
