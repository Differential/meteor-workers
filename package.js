Package.describe({
  name: 'schnie:workers',
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
    'percolatestudio:synced-cron@1.0.0'
  ], 'server');

  api.addFiles([
    'lib/init.coffee',
    'lib/Job.coffee'
  ], 'server');

  api.export('Job', 'server');
});
