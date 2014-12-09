Workers
==============================================================================
This package lets you easily push jobs onto a mongo-backed queue and have them asynchronously picked up and ran by a separate 'headless' meteor process.

## Goals
- The code you write for you job handlers should look and behave just like the rest of your application code, and have access to the meteor API you know and love.
- Self contained deployment.  We wanted to be able to deploy our app just like we always have and not have a separate deployment for the application handling the jobs.
- Simple interface with minimal configuration and setup.

## Simple Usage
### Add a job
````
Job.push "load-retention",
  projectId: projectId
  cohortInterval: "day"
````

### Handle a job
````
class @LoadRetentionJob extends Job
  handleJob: ->
    project = Project.findOne @job.projectId

  unless project
    throw new Error "Project not found, could not load retention!"
````

## Docs
Currently all methods are only available on the server.

### To add a job:
`Job.push (name, job, [options], [callback])`
##### Arguments
- name - (String) Dash separated name of your job
- job - (Object) The job parameters.  Will be available to the job handler.
- options - (Object) - Optional. [Monq](https://www.npmjs.org/package/monq) parameters to be added to the job (delay, etc).
- callback (Function) - Optional. Callback to run after job has successfully been added to the queue.

### To handle a job:
Extend the `Job` class and implement the `handleJob` method.  The class name must end with `Job` and be globally available.  Classes ending in `Job` are automatically registered to handle their corresponding jobs when they are dequeued.  "load-retention" will be handled by `LoadRetentionJob`.  Inside your job handler `this.job` will be the hash that you passed in as the second parameter to `Job.push`.  You can also run jobs on a cron schedule, rather than pushing them into the queue.  To do this, just implement a static method `setupCron(parser)` on your job class.  We use percolate-studio's [synced-cron](https://atmospherejs.com/percolatestudio/synced-cron) package for scheduling.  You will be passed a [later.js](http://bunkat.github.io/later) `parser` object as the only argument.
````
class @CleanUpJob extends Job
  @setupCron: (parser) ->
    parser.recur().on(0).hour()

  handleJob: ->
    doCleanUpStuff()
````

### Logging
`Job.log([agruments])`
- This will `console.log` your arguments with a label prepended, denoting which process is being used.  (Master, PID 12001, PID 12002, etc)

### Configuration
Uses Meteor.settings API.
````
{
  "workers": {
    "amount": 2
  }
}
````
- This will set up 2 background workers.  If you are deploying to multiple servers, or servos (modulus), this will fire up 2 workers on each.
