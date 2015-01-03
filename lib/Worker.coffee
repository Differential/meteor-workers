monq = Npm.require("monq")(process.env.MONGO_URL)

class Worker

  @init: ->
    # Load up workers
    workersPerProcess = Meteor.settings?.workers?.perProcess or 1
    for worker in [1..workersPerProcess]
      Workers.workers.push monq.worker ["jobs"]

    # Look for classes that end in "Job" and register them
    # with the default handler (dispatcher)
    Workers.withJobs (val, key) ->
      handlers = {}
      handlers[key] = Meteor.bindEnvironment Job.handler
      _.each Workers.workers, (worker) ->
        worker.register handlers
    Workers.log "Initialized worker process."


  # Stagger out polling on workers
  @start: ->
    _.each Workers.workers, (worker, i) ->
      Meteor.setTimeout ->
        worker.start()
      , 100 * i
    Workers.log "Started #{Workers.workers.length} workers."


  @stop: ->
    _.each Workers.workers, (worker, i) ->
      worker.stop()
    Workers.log "Stopped #{Workers.workers.length} workers."
