# The purpose of this module is to:
# - Create a Job class with an interface for pushing new jobs to a queue
#   and handling those jobs when they are dequeued.  The job class
#   is constructed differently depending on what type of process
#   this code gets executed in (master, worker).



cluster = Npm.require "cluster"
os = Npm.require "os"
monq = Npm.require("monq")(process.env.MONGO_URL)

# Iterate over jobs
withJobs = (cb) ->
  _.each global, (val, key) ->
    cb(val, key) if _.endsWith(key, "Job") and key isnt "Job"


#
# Job Class
# - Shared between master and worker processes
#
class Job
  # Interface for adding new jobs
  @queue: monq.queue "jobs"

  # Static monq worker objects
  @workers = []


  constructor: (@params, @metadata) ->


  @push: (job = new Job, options = {}, callback) ->
    if _.isFunction options
      callback = options
      options = {}

    if callback
      callback = Meteor.bindEnvironment callback
    else
      callback = (error, job) ->
        if error then Job.log "Error enqueing job:", error
        error?

    defaultOptions = attempts: count: 10, delay: 1000, strategy: "exponential"
    settingsOptions = Meteor.settings?.workers?.monq
    options = _.extend defaultOptions, settingsOptions, options

    className = job.constructor.name

    job.params._workersId = Random.id()
    params = job.params

    @queue.enqueue className, params, options, callback

  @log: ->
    args = _.values arguments
    args.unshift if cluster.isMaster then "MASTER:" else "PID #{process.pid}:"
    console.log.apply @, args

  @getJobMetadata = (workersId) ->
    Jobs.findOne "params._workersId": workersId,
      fields: params: false


  @initAsScheduler = ->
    withJobs (val, key) ->
      if global[key].setupCron?
        SyncedCron.add
          name: "#{key} (Cron)"
          schedule: global[key].setupCron
          job: -> Job.push key

    # Kick of cron job polling
    SyncedCron.options = log: false, utc: true
    SyncedCron.start()
    Job.log "Started job scheduler!"


  @initAsWorker = ->
    # Load up workers
    workersPerProcess = Meteor.settings?.workers?.perProcess or 1
    for worker in [1..workersPerProcess]
      Job.workers.push monq.worker ["jobs"]

    # Look for classes that end in "Job" and register them
    # with the default handler (dispatcher)
    withJobs (val, key) ->
      handlers = {}
      handlers[key] = Meteor.bindEnvironment Job.handler
      _.each Job.workers, (worker) ->
        worker.register handlers

    # Stagger out polling on workers
    _.each Job.workers, (worker, i) ->
      Meteor.setTimeout ->
        worker.start()
      , 100 * i

    Job.log "Started worker process with #{Job.workers.length} workers!"



  # Generic job handler for all jobs
  # - Evaluates the job type specified in Job.push
  #   and instantiates an approriate handler and runs handleJob.
  @handler = (job, callback) ->
    # Instantiate approprite job handler
    meta = Job.getJobMetadata job._workersId
    className = meta.name
    handler = new global[className](job, meta)

    _ex = null

    try
      # Before hook
      handler.beforeJob()

      # Handle the job
      result = handler.handleJob()

      # Forward results to monq callback
      callback null, result

    catch ex
      _ex = ex
      Job.log "Error in #{className} handler:\n", _ex
      callback ex

    finally
      # After hook
      handler.afterJob _ex


  # Specific job classes should implement this
  # - Error handlers are fiber/meteor aware as usual
  # - Throw errors from handler if you cannot handle message for any reason
  # - Return value of handleJob will be put in the result hash on the job
  handleJob: ->
    throw new Error "Message handler not implemented!"

  # Job lifecycle callbacks
  beforeJob: ->
  afterJob: (exception) ->
