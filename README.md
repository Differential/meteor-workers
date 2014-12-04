Workers
==============================================================================
This package lets you easily push jobs onto a mongo-backed queue and have them asynchronously picked up and ran by a separate meteor 'headless' meteor process.

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
    @project = Project.findOne @job.projectId

  unless @project
    throw new Error "Project not found, could not load retention!"
````

## Docs
Currently all methods are only available on the server.

### To add a job:
`Job.push (name, job, [options], [callback])`
##### Arguments
- name - (String) Dash separated name of your job
- job - (Object) The job parameters.  Will be available to the job handler.
- options - (Object) - Optional. Monq parameters to be added to the job (delay, etc).
- callback (Function) - Optional. Callback to run after job has successfully been added to the queue.

### To handle a job:
Extend the `Job` class and implement the `handleJob` method.  Inside your job handler `this.job` will be the hash that you passed in as the second parameter to `Job.push`.

### Logging
`Job.log([agruments])`
- This will `console.log` your arguments with a label prepended, denoting which process is being used.  (Master, PID 12001, PID 12002, etc)
