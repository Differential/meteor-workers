cluster = Npm.require "cluster"
os = Npm.require "os"


class WorkersUtil

  @withJobs: (cb) ->
  # Iterate over jobs
    _.each global, (val, key) ->
      cb(val, key) if _.endsWith(key, "Job") and key isnt "Job"

  @log: ->
    args = _.values arguments
    args.unshift if cluster.isMaster then "MASTER:" else "PID #{process.pid}:"
    console.log.apply @, args


  @start: (workersToStart, startScheduler) ->
    workersToStart = workersToStart or Meteor.settings?.workers?.processes or 1
    startScheduler = startScheduler or Meteor.settings?.workers?.cron?.disable

    if _.size(cluster.workers) is 0
      workersToStart = if workersToStart is 0 then 0 else workersToStart - 1
      for i in [0..workersToStart] by 1
        cluster.fork PORT: 0

      # May not be the best solution, but give some time for all
      # master processes across the deployment to start.
      # Then spwan a scheduler if this is the chosen master process.
      unless startScheduler
        Meteor.setTimeout ->
          chosen = SchedulerHelper.findOne()
          unless chosen
            throw new Error "Could not select a scheduler!"

          # If this process has been chosen
          if chosen.hostname is os.hostname()
            cluster.fork PORT: 0, WORKERS_SCHEDULER: true
        , Meteor.settings?.workers.cron?.startDelay or 60000
      else
        WorkersUtil.log "Scheduler is disabled."
    else
      WorkersUtil.log "Workers already started."


  @stop: ->
    if cluster.isMaster
      _.each cluster.workers, (worker) ->
        worker.kill()
