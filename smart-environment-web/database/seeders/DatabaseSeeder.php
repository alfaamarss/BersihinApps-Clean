<?php

namespace Database\Seeders;

use App\Models\User;
// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            RolePermissionSeeder::class,
            MenuSeeder::class,
            AdminFeatureMenuSeeder::class,
            WasteSeeder::class,
            PocketSizeSeeder::class,
            WastePricingSeeder::class,
            AreaSeeder::class,
            RwSeeder::class,
            GarbageDumpSeeder::class,
            ArticleSeeder::class,
            // ScheduleSeeder::class,
        ]);

        $admin = User::firstOrCreate(
            ['email' => 'admin@example.com'],
            [
                'name' => 'Admin User',
                'email' => 'admin@example.com',
                'password' => bcrypt('password'),
                'email_verified_at' => now(),
            ]
        );
        try { $admin->assignRole('admin'); } catch (\Throwable $e) { /* ignore */ }
    try { $admin->assignRole(\Spatie\Permission\Models\Role::findByName('admin', 'web')); } catch (\Throwable $e) { /* ignore */ }
    try { $admin->assignRole(\Spatie\Permission\Models\Role::findByName('admin', 'api')); } catch (\Throwable $e) { /* ignore */ }

        $collector = User::firstOrCreate(
            ['email' => 'collector@example.com'],
            [
                'name' => 'Collector',
                'email' => 'collector@example.com',
                'password' => bcrypt('password'),
                'email_verified_at' => now(),
            ]
        );
        try { $collector->assignRole('collector'); } catch (\Throwable $e) { /* ignore */ }
    try { $collector->assignRole(\Spatie\Permission\Models\Role::findByName('collector', 'web')); } catch (\Throwable $e) { }
    try { $collector->assignRole(\Spatie\Permission\Models\Role::findByName('collector', 'api')); } catch (\Throwable $e) { }

        $warga = User::firstOrCreate(
            ['email' => 'warga@example.com'],
            [
                'name' => 'Warga',
                'email' => 'warga@example.com',
                'password' => bcrypt('password'),
                'email_verified_at' => now(),
            ]
        );
        try { $warga->assignRole('warga'); } catch (\Throwable $e) { /* ignore */ }
    try { $warga->assignRole(\Spatie\Permission\Models\Role::findByName('warga', 'web')); } catch (\Throwable $e) { }
    try { $warga->assignRole(\Spatie\Permission\Models\Role::findByName('warga', 'api')); } catch (\Throwable $e) { }
    }
}
