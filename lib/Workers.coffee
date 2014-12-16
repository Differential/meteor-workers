# The purpose of this module is to:
# - Create a Job class with an interface for pushing new jobs to a queue
#   and handling those jobs when they are dequeued.

cluster = Npm.require "cluster"
monq = Npm.require("monq")(process.env.MONGO_URL)

class Workers
  # Interface for adding new jobs
  @queue: monq.queue "jobs"


  # Static monq worker objects
  @workers = []


  # Iterate over jobs
  @withJobs = (cb) ->
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


  @initAsScheduler = ->
    @withJobs (val, key) ->
      if global[key].setupCron?

        # Add a synced cron job to push our actual job
        # onto the queue
        SyncedCron.add
          name: "#{key} (Cron)"
          schedule: global[key].setupCron
          job: -> Job.push new global[key]()

    # Kick of cron job polling
    SyncedCron.options =
      log: Meteor.settings?.workers?.cron?.log
      utc: true

    SyncedCron.start()

    Workers.log "Started job scheduler!"


  @initAsWorker = ->
    # Load up workers
    workersPerProcess = Meteor.settings?.workers?.perProcess or 1
    for worker in [1..workersPerProcess]
      Workers.workers.push monq.worker ["jobs"]

    # Look for classes that end in "Job" and register them
    # with the default handler (dispatcher)
    @withJobs (val, key) ->
      handlers = {}
      handlers[key] = Meteor.bindEnvironment Job.handler
      _.each Workers.workers, (worker) ->
        worker.register handlers

    # Stagger out polling on workers
    _.each Workers.workers, (worker, i) ->
      Meteor.setTimeout ->
        worker.start()
      , 100 * i

    Workers.log "Started worker process with #{Workers.workers.length} workers!"
