<?php

namespace App\Console\Commands;

use Illuminate\Foundation\Console\ServeCommand as BaseServeCommand;
use Symfony\Component\Process\PhpExecutableFinder;

class ServeCommand extends BaseServeCommand
{
    /**
     * Get the full server command with SQLite extensions enabled.
     *
     * @return array
     */
    protected function serverCommand()
    {
        $server = file_exists(base_path('server.php'))
            ? base_path('server.php')
            : base_path('vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php');

        $extDir = base_path('../.php_ext/usr/lib/php/20230831');
        $sqliteExt = "{$extDir}/sqlite3.so";
        $pdoSqliteExt = "{$extDir}/pdo_sqlite.so";

        $phpBinary = (new PhpExecutableFinder)->find(false) ?: 'php';

        $command = [
            $phpBinary,
        ];

        if (file_exists($sqliteExt) && file_exists($pdoSqliteExt)) {
            $command[] = '-d';
            $command[] = "extension={$sqliteExt}";
            $command[] = '-d';
            $command[] = "extension={$pdoSqliteExt}";
        }

        $command[] = '-S';
        $command[] = $this->host().':'.$this->port();
        $command[] = $server;

        return $command;
    }
}

