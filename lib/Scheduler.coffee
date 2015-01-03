class Scheduler

  @init: ->
    Workers.withJobs (val, key) ->
      if global[key].setupCron?

        # Add a synced cron job to push our actual job
        # onto the queue
        SyncedCron.add
          name: "#{key} (Cron)"
          schedule: global[key].setupCron
          job: -> Workers.push new global[key]()

    # Kick of cron job polling
    SyncedCron.options =
      log: Meteor.settings?.workers?.cron?.log
      utc: true

    Workers.log "Initalized job scheduler."


  @start: ->
    SyncedCron.start()
    Workers.log "Started job scheduler."


  @stop: ->
    SyncedCron.stop()
    Workers.log "Stopped job scheduler."
