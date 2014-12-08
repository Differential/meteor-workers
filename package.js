Package.describe({
  name: 'differential:workers',
  summary: 'Spawn headless worker meteor processes to work on async jobs',
  version: '0.0.1'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');

  Npm.depends({
    monq: '0.3.1'
  });

  api.use([
    'coffeescript',
    'mongo',
    'percolatestudio:synced-cron@1.0.0'
  ], 'server');

  api.addFiles([
    'collections/jobs.coffee',
    'lib/Job.coffee',
    'lib/init.coffee'
  ], 'server');

  api.export('Job', 'server');
  api.export('Jobs', 'server');
});
