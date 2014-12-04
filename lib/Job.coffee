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
  @addJob: (type, job = {}, options, callback) ->
    if _.isFunction options
      callback = options

    job._messageType = type
    job._enqueued = new Date

    defaultOptions = attempts: count: 10, delay: 15, strategy: "exponential"
    options = _.extend defaultOptions, options
    @queue.enqueue type, job, options, callback or (error, job) ->
      if error
        Job.log error
    error?

  @push: (type, job, options, callback) ->
    @addJob type, job, options, callback

  @log: ->
    args = _.values arguments
    args.unshift if cluster.isMaster then "MASTER:" else "PID #{process.pid}:"
    console.log.apply @, args



#
# WORKER PROCESS
# - Extend worker version of Job class and start polling
#
if cluster.isWorker

  # When a worker proc recieves IPC message from master
  # process.on "message", Meteor.bindEnvironment (job) ->

  # Static monq worker object
  Job.worker = monq.worker ["jobs"]


  # Generic job handler for all jobs
  # - Evaluates the job type specified in Job.push
  #   and instantiates an approriate handler and runs handleJob.
  Job.handler = (job, callback) ->
    try
      # Instantiate approprite job handler
      className = "#{_.classify job._messageType}Job"
      handler = new global[className](job)

      # Before hook
      handler.beforeJob()

      # Handle the job
      result = handler.handleJob()

      # After hook
      handler.afterJob()

      # Forward results to monq callback
      callback null, result

    catch error
      Job.log error
      handler.onError error, job
      callback error

  # Specific job classes should implement this
  # - Error handlers are fiber/meteor aware as usual
  # - Throw errors from handler if you cannot handle message for any reason
  # - Return value of handleJob will be put in the result hash on the job
  Job::handleJob = ->
    throw new Error "Message handler not implemented!"

  # Sets the job up as 'this' inside job callbacks
  Job::constructor = (@job) ->

  # Default job lifecycle callbacks
  Job::beforeJob = ->
  Job::afterJob = ->
  Job::onError = ->
