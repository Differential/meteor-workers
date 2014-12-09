# The purpose of this module is to:
# - Fork off worker processes, running the same meteor app as master
#   but do not handle any incoming requests.
# - Start polling for new jobs in the worker processes.

cluster = Npm.require "cluster"
os = Npm.require "os"


# Iterate over jobs
withJobs = (cb) ->
  _.each global, (val, key) ->
    cb(val, key) if _.endsWith(key, "Job") and key isnt "Job"

getJobType = (str) ->
  dashed = _.dasherize str
  dashed.substring 1, dashed.indexOf "-job"


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
      withJobs (val, key) ->
        if global[key].setupCron?
          jobType = getJobType key
          SyncedCron.add
            name: "#{key} (Cron)"
            schedule: global[key].setupCron
            job: -> Job.push jobType

      # Kick of cron job polling
      SyncedCron.options = log: false, utc: true
      SyncedCron.start()
      Job.log "Started job scheduler!"

    else
      # Look for classes that end in "Job" and register them
      # with the default handler (dispatcher)
      withJobs (val, key) ->
        jobType = getJobType key
        handlers = {}
        handlers[jobType] = Meteor.bindEnvironment Job.handler
        _.each Job.workers, (worker) ->
          worker.register handlers

      # Stagger out polling on workers
      _.each Job.workers, (worker, i) ->
        Meteor.setTimeout ->
          worker.start()
        , 100 * i

      Job.log "Started worker process with #{Job.workers.length} workers!"
