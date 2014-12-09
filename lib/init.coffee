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

    # Master process event logging
    # cluster.on "online", (worker) ->
      # Job.log "Started worker with PID #{worker.process.pid}"

    # cluster.on "exit", (worker, code, signal) ->
    #   Job.log "Worker with PID #{worker.process.pid} exited!"

    # Fork off worker processes
    createProcess = ->
      proc = cluster.fork PORT: 0

    workersToStart = Meteor.settings?.workers?.processes or 1
    workersToStart++
    createProcess() for proc in [1..workersToStart]



  #
  # WORKER PROCESS
  # - Extend worker version of Job class and start polling
  #
  if cluster.isWorker

    # All worker processes register themselves into a single document collection
    # on startup.  The last one to start up across all deployments
    # will end up being the scheduler.

    Scheduler.update name: "scheduler",
      $set: hostname: os.hostname(), pid: process.pid
    , upsert: true


    # May not be the best solution, but give some time for all
    # processes across the deployment to start.
    # Then choose the scheduler, and start all others as workers.
    Meteor.setTimeout ->
      chosen = Scheduler.findOne()
      unless chosen
        throw new Error "Could not select a scheduler!"

      isScheduler = chosen.hostname is os.hostname() and chosen.pid is process.pid

      # Look for classes that end in "Job" and register them
      # with the default handler (dispatcher)
      _.each global, (val, key) ->
        if _.endsWith(key, "Job") and key isnt "Job"
          dashed = _.dasherize key
          jobType = dashed.substring 1, dashed.indexOf "-job"
          handlers = {}
          handlers[jobType] = Meteor.bindEnvironment Job.handler
          _.each Job.workers, (worker) ->
            worker.register handlers

          if isScheduler and global[key].setupCron?
            SyncedCron.add
              name: "#{key} (Cron)"
              schedule: global[key].setupCron
              job: ->
                Job.push jobType


      if isScheduler
        # Kick of cron job polling
        SyncedCron.options = log: false, utc: true
        SyncedCron.start()
        Job.log "Started job scheduler!"
      else
        # Kick off polling
        _.each Job.workers, (worker, i) ->
          worker.start()

        Job.log "Started worker process with #{Job.workers.length} workers!"

    , 5000
