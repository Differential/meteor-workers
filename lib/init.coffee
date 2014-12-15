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
    Job.log "Requeued #{count} jobs."

    # Fork off worker processes
    createProcess = ->
      proc = cluster.fork PORT: 0

    workersToStart = Meteor.settings?.workers?.processes or 1
    createProcess() for proc in [1..workersToStart]


    # All master processes register themselves into a single document collection
    # on startup.  The last one to start up across all deployments
    # will spawn the the scheduler.
    Scheduler.update name: "scheduler",
      $set: hostname: os.hostname()
    , upsert: true


    # May not be the best solution, but give some time for all
    # master processes across the deployment to start.
    # Then spwan a scheduler if this is the chosen master process.
    Meteor.setTimeout ->
      chosen = Scheduler.findOne()
      unless chosen
        throw new Error "Could not select a scheduler!"

      # If this process has been chosen
      if chosen.hostname is os.hostname()
        cluster.fork PORT: 0, WORKERS_SCHEDULER: true
    , 10000

  #
  # WORKER PROCESS
  # - Extend worker version of Job class and start polling
  #
  if cluster.isWorker

    if process.env.WORKERS_SCHEDULER
      Job.initAsScheduler()
    else
      Job.initAsWorker()
