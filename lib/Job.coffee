# The purpose of this module is to:
# - Create a Job class with an interface for pushing new jobs to a queue
#   and handling those jobs when they are dequeued.  The job class
#   is constructed differently depending on what type of process
#   this code gets executed in (master, worker).



cluster = Npm.require "cluster"
os = Npm.require "os"
monq = Npm.require("monq")(process.env.MONGO_URL)



#
# Job Class
# - Shared between master and worker processes
#
class Job

  # Interface for adding new jobs
  @queue: monq.queue "jobs"

  # Shared method to add to queue
  @push: (type, job = {}, options, callback) ->
    if _.isFunction options
      callback = options
      options = null

    if callback
      callback = Meteor.bindEnvironment callback

    defaultOptions = attempts: count: 10, delay: 1000, strategy: "exponential"
    options = _.extend defaultOptions, options
    @queue.enqueue type, job, options, callback or (error, job) ->
      if error
        Job.log error
    error?

  @log: ->
    args = _.values arguments
    args.unshift if cluster.isMaster then "MASTER:" else "PID #{process.pid}:"
    console.log.apply @, args

  @getJobMetadata = (job) ->
    Jobs.findOne params: job,
      fields: params: false


#
# WORKER PROCESS
# - Extend worker version of Job class and start polling
#
if cluster.isWorker

  # When a worker proc recieves IPC message from master
  # process.on "message", Meteor.bindEnvironment (job) ->

  # Static monq worker object
  Job.workers = []

  addWorker = ->
    Job.workers.push monq.worker ["jobs"]

  workersPerProcess = Meteor.settings?.workers?.perProcess or 1
  for worker in [1..workersPerProcess]
    addWorker()


  # Generic job handler for all jobs
  # - Evaluates the job type specified in Job.push
  #   and instantiates an approriate handler and runs handleJob.
  Job.handler = (job, callback) ->
    _ex = null
    try
      # Instantiate approprite job handler
      meta = Job.getJobMetadata job
      className = "#{_.classify meta.name}Job"
      handler = new global[className](job, meta)

      # Before hook
      handler.beforeJob()

      # Handle the job
      result = handler.handleJob()

      # Forward results to monq callback
      callback null, result

    catch ex
      _ex = ex
      Job.log ex
      callback ex

    finally
      # After hook
      handler.afterJob _ex

  # Specific job classes should implement this
  # - Error handlers are fiber/meteor aware as usual
  # - Throw errors from handler if you cannot handle message for any reason
  # - Return value of handleJob will be put in the result hash on the job
  Job::handleJob = ->
    throw new Error "Message handler not implemented!"

  # Sets the job up as 'this' inside job callbacks
  Job::constructor = (@job, @metadata) ->

  # Default job lifecycle callbacks
  Job::beforeJob = ->
  Job::afterJob = (exception) ->
