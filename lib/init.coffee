Monq = Npm.require("monq")(process.env.MONGO_URL)

withJobs = (cb) ->
  _.each global, (val, key) ->
    cb(val, key) if _.endsWith(key, "Job") and key isnt "Job"


Cluster.startupMaster ->
  count = Jobs.update status: "dequeued",
    $set: status: "queued"
  , multi: true
  Cluster.log "Requeued #{count} jobs."

  unless Meteor.settings?.workers?.cron?.disable
    SyncedCron.options =
      log: Meteor.settings?.workers?.cron?.log
      utc: true
      collectionName: "scheduler"

    withJobs (val, key) ->
      if global[key].setupCron?

        SyncedCron.add
          name: "#{key} (Cron)"
          schedule: global[key].setupCron
          job: ->
            Job.push new global[key]

    SyncedCron.start()


Cluster.startupWorker ->
  monqWorkers = Meteor.settings?.workers?.count or 1
  i = 0
  while i < monqWorkers
    i++
    Meteor.setTimeout ->
      worker = Monq.worker ["jobs"]

      withJobs (val, key) ->
        handlers = {}
        handlers[key] = Meteor.bindEnvironment Job.handler
        worker.register handlers

      worker.on "complete", Meteor.bindEnvironment (data) ->
        Jobs.remove "params._id": data.params._id

      worker.start()
    , 100 * i

  Cluster.log "Started #{monqWorkers} monq workers."
