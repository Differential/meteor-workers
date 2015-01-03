cluster = Npm.require "cluster"

#
# Abstract Job class for all actual jobs to subclass
# - Shared between master and worker processes
#
class Job

  constructor: (@params = {}, @metadata) ->


  @getMetadata: (id) ->
    Jobs.findOne "params._id": id,
      fields: params: false


  # Generic job handler for all jobs
  # - Evaluates the job type specified in Job.push
  #   and instantiates an approriate handler and runs handleJob.
  @handler: (job, callback) ->
    # Instantiate approprite job handler
    meta = Job.getMetadata job._id
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
      Workers.log "Error in #{className} handler:\n", _ex
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
