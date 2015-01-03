cluster = Npm.require "cluster"
os = Npm.require "os"
monq = Npm.require("monq")(process.env.MONGO_URL)


class Workers

  # Interface for adding new jobs
  @queue: monq.queue "jobs"


  # Static monq worker objects
  @workers = []


  @withJobs: (cb) ->
  # Iterate over jobs
    _.each global, (val, key) ->
      cb(val, key) if _.endsWith(key, "Job") and key isnt "Job"


  @log: ->
    args = _.values arguments
    args.unshift if cluster.isMaster then "MASTER:" else "PID #{process.pid}:"
    console.log.apply @, args


  @push: (job, options, callback) ->
    if _.isFunction options
      callback = options
      options = {}

    if callback
      callback = Meteor.bindEnvironment callback
    else
      callback = (error, job) ->
        if error then Workers.log "Error enqueing job:", error
        error?

    defaultOptions = attempts: count: 10, delay: 1000, strategy: "exponential"
    settingsOptions = Meteor.settings?.workers?.monq
    options = _.extend defaultOptions, settingsOptions, options

    className = job.constructor.name

    job.params._id = Random.id()
    params = job.params

    @queue.enqueue className, params, options, callback


  @requeue: ->
    # If server(s) have been restarted or workers stopped,
    # re-queue any dequeued jobs
    # - These are likely jobs that were in the middle of processing
    #   when the process was killed.
    # XXX: Not fully tested, may require more thought
    count = Jobs.update status: "dequeued",
      $set: status: "queued"
    , multi: true
    Workers.log "Requeued #{count} jobs."


  @start: (workersToStart, startScheduler) ->
    workersToStart = workersToStart or Meteor.settings?.workers?.processes or 1
    startScheduler = startScheduler or Meteor.settings?.workers?.cron?.disable

    Workers.requeue()

    if _.size(cluster.workers) is 0

      workersToStart = if workersToStart is 0 then 0 else workersToStart - 1
      for i in [0..workersToStart] by 1
        worker = cluster.fork PORT: 0
        worker.on "exit", ->
          Workers.log "Worker process killed."

      # May not be the best solution, but give some time for all
      # master processes across the deployment to start.
      # Then spwan a scheduler if this is the chosen master process.
      unless startScheduler

        # All master processes register themselves into a single document collection
        # on startup.  The last one to start up across all deployments
        # will spawn the the scheduler.
        SchedulerHelper.update name: "scheduler",
          $set: hostname: os.hostname()
        , upsert: true

        Meteor.setTimeout ->
          chosen = SchedulerHelper.findOne()
          unless chosen
            throw new Error "Could not select a scheduler!"

          # If this process has been chosen
          if chosen.hostname is os.hostname()
            scheduler = cluster.fork PORT: 0, WORKERS_SCHEDULER: true
            scheduler.on "exit", ->
              Workers.log "Scheduler process killed."

        , Meteor.settings?.workers.cron?.startDelay or 60000

      else
        Workers.log "Scheduler is disabled."

    else
      Workers.log "Workers already started."


  @stop: ->
    if cluster.isMaster
      _.each cluster.workers, (worker) ->
        worker.kill()
