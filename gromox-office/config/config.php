<?php
$CONFIG = array (
  'overwritewebroot' => '/files',
  'datadirectory' => '/var/lib/grommunio-files/data',
  'logfile' => '/var/log/grommunio-files/files.log',
  'theme' => 'theme-grommunio',
  'logtimezone' => 'UTC',
  'apps_paths' =>
  array (
    0 =>
    array (
      'path' => '/usr/share/grommunio-files/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 =>
    array (
      'path' => '/var/lib/grommunio-files/apps-external',
      'url' => '/apps-external',
      'writable' => true,
    ),
  ),
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'filelocking.enabled' => true,
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'upgrade.disable-web' => true,
  'upgrade.automatic-app-update' => true,
  'updater.server.url' => '127.0.0.1',
  'integrity.check.disabled' => false,
);