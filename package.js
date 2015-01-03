Package.describe({
  name: 'differential:workers',
  summary: 'Spawn headless worker meteor processes to work on async jobs',
  version: '1.0.0',
  git: 'https://github.com/Differential/meteor-workers'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');

  Npm.depends({
    monq: '0.3.1'
  });

  api.use([
    'coffeescript',
    'mongo',
    'random',
    'percolatestudio:synced-cron@1.0.0',
    'wizonesolutions:underscore-string@1.0.0'
  ], 'server');

  api.addFiles([
    'collections/scheduler.coffee',
    'collections/jobs.coffee',
    'lib/Workers.coffee',
    'lib/Worker.coffee',
    'lib/Scheduler.coffee',
    'lib/Job.coffee',
    'lib/init.coffee'
  ], 'server');

  api.export(['Workers', 'Worker', 'Scheduler', 'Job', 'Jobs'], 'server');
});
