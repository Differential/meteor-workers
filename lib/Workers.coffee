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


  @push: (job, options, callback) ->
    if _.isFunction options
      callback = options
      options = {}

    if callback
      callback = Meteor.bindEnvironment callback
    else
      callback = (error, job) ->
        if error then WorkersUtil.log "Error enqueing job:", error
        error?

    defaultOptions = attempts: count: 10, delay: 1000, strategy: "exponential"
    settingsOptions = Meteor.settings?.workers?.monq
    options = _.extend defaultOptions, settingsOptions, options

    className = job.constructor.name

    job.params._id = Random.id()
    params = job.params

    @queue.enqueue className, params, options, callback


  @init: ->
    # Load up workers
    workersPerProcess = Meteor.settings?.workers?.perProcess or 1
    for worker in [1..workersPerProcess]
      Workers.workers.push monq.worker ["jobs"]

    # Look for classes that end in "Job" and register them
    # with the default handler (dispatcher)
    WorkersUtil.withJobs (val, key) ->
      handlers = {}
      handlers[key] = Meteor.bindEnvironment Job.handler
      _.each Workers.workers, (worker) ->
        worker.register handlers
    WorkersUtil.log "Initialized worker process."


  # Stagger out polling on workers
  @start: ->
    _.each Workers.workers, (worker, i) ->
      Meteor.setTimeout ->
        worker.start()
      , 100 * i
    WorkersUtil.log "Started #{Workers.workers.length} workers."


  @stop: ->
    _.each Workers.workers, (worker, i) ->
      worker.stop()
    WorkersUtil.log "Stopped #{Workers.workers.length} workers."
