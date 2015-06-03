Workers
==============================================================================
This package lets you easily push jobs onto a mongo-backed queue and have them asynchronously picked up and ran by a separate 'headless' meteor process.

## Goals
- The code you write for you job handlers should look and behave just like the rest of your application code, and have access to the meteor API and packages you know and love.
- Self contained deployment.  We wanted to be able to deploy our app just like we always have and not have a separate deployment for the application handling the jobs.
- Simple interface with minimal configuration and setup.

## Simple Usage
### Install package
```
meteor add differential:workers
```

### Add a job
````
Job.push new LoadRetentionJob
  projectId: projectId
  cohortInterval: "day"
````

### Handle a job
````
class @LoadRetentionJob extends Job
  handleJob: ->
    project = Project.findOne @params.projectId

    unless project
      throw new Error "Project not found, could not load retention!"
````

## Docs
Currently all methods are only available on the server.

### To add a job:
````
job = new LoadRetentionJob projectId: projectId
Job.push (job, [options], [callback])
````
##### Arguments
- job - (Object) The job parameters.  Will be available to the job handler.
- options - (Object) - Optional. [Monq](https://www.npmjs.org/package/monq) parameters to be added to the job (delay, etc).
- callback (Function) - Optional. Callback to run after job has successfully been added to the queue.

### To handle a job:
Extend the `Job` class and implement the `handleJob` method.  The class name must end with `Job` and be globally available.  Classes ending in `Job` are automatically registered to handle their corresponding jobs when they are dequeued.  Inside your job handler `this.params` will be the hash that you passed in as the parameter to `new Job()`, and `this.getMetadata(this.params._id)` will return additional information about the job in the queue used by monq.  You can also run jobs on a cron schedule, rather than pushing them into the queue.  To do this, just implement a static method `setupCron(parser)` on your job class.  We use percolate-studio's [synced-cron](https://atmospherejs.com/percolatestudio/synced-cron) package for scheduling.  You will be passed a [later.js](http://bunkat.github.io/later) `parser` object as the only argument.
````
class @CleanUpJob extends Job
  @setupCron: (parser) ->
    parser.recur().on(0).hour()

  handleJob: ->
    doCleanUpStuff()
````
You can also implement `afterJob` in your handler class.  If an error is thrown in your handler, it will be passed in as the only argument to this function, otherwise it will be `undefined`.


### Configuration
Uses Meteor.settings API.
````
{
  "cluster": {
    "count": 2
  },
  "workers": {
    "count": 10,
    "monq": {
      // default monq parameters overrides
    },
    "cron": {
      "log": false, // show SyncedCron logging
      "disable": false // disable cron scheduler (nice for debugging sometimes)
    }
  },
}
````
- This will set up 2 background worker processes.  If you are deploying to multiple servers, or servos (modulus), this will fire up 2 workers on each.  It will then start up 10 [Monq](https://www.npmjs.org/package/monq) workers on each process.
