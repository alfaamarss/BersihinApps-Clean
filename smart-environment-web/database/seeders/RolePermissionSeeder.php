<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

class RolePermissionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // reset cached roles and permissions
    app(\Spatie\Permission\PermissionRegistrar::class)->forgetCachedPermissions();

        // Base permissions for core entities + areas
        $basePermissions = [
            // User Management
            'read_user', 'create_user', 'update_user', 'delete_user',
            // Role Management
            'read_role', 'create_role', 'update_role', 'delete_role',
            // Menu Management
            'read_menu', 'create_menu', 'update_menu', 'delete_menu',
            // Permission Management
            'read_permission', 'create_permission', 'update_permission', 'delete_permission',
            // Areas
            'read_area', 'create_area', 'update_area', 'delete_area',
            // RWs
            'read_rw', 'create_rw', 'update_rw', 'delete_rw',
            // Schedules
            'read_schedule', 'create_schedule', 'update_schedule', 'delete_schedule',
            // Service Accounts
            'read_service_account', 'create_service_account', 'update_service_account', 'delete_service_account',
            // Wastes
            'read_waste', 'create_waste', 'update_waste', 'delete_waste',
            // Pocket Sizes
            'read_pocket_size', 'create_pocket_size', 'update_pocket_size', 'delete_pocket_size',
            // Waste Pricings
            'read_waste_pricing', 'create_waste_pricing', 'update_waste_pricing', 'delete_waste_pricing',
            // Articles
            'read_article', 'create_article', 'update_article', 'delete_article',
            // Invoices
            'read_invoice', 'create_invoice', 'update_invoice', 'delete_invoice',
            // Payments
            'read_payment', 'create_payment', 'update_payment', 'delete_payment',
            // Collector Assignments
            'read_collector_assignment', 'create_collector_assignment', 'update_collector_assignment', 'delete_collector_assignment',
            // Complaints
            'read_complaint', 'create_complaint', 'update_complaint', 'delete_complaint',
            // Waste Deliveries
            'read_waste_delivery', 'create_waste_delivery', 'update_waste_delivery', 'delete_waste_delivery',
            // Waste Collections
            'read_waste_collection', 'create_waste_collection', 'update_waste_collection', 'delete_waste_collection',
            // Waste Carries
            'read_waste_carry', 'create_waste_carry', 'update_waste_carry', 'delete_waste_carry',
            // Garbage Dumps
            'read_garbage_dump', 'create_garbage_dump', 'update_garbage_dump', 'delete_garbage_dump',
            // Audit Logs
            'read_audit_log', 'create_audit_log', 'update_audit_log', 'delete_audit_log',
        ];

        // Create roles/permissions for both guards used by the app
        foreach (['api', 'web'] as $guard) {
            foreach ($basePermissions as $perm) {
                Permission::firstOrCreate(['name' => $perm, 'guard_name' => $guard]);
            }

            $adminRole = Role::firstOrCreate(['name' => 'admin', 'guard_name' => $guard]);
            $collectorRole = Role::firstOrCreate(['name' => 'collector', 'guard_name' => $guard]);
            $userRole = Role::firstOrCreate(['name' => 'warga', 'guard_name' => $guard]);
            $residentRole = Role::firstOrCreate(['name' => 'resident', 'guard_name' => $guard]);

            // Admin has all permissions in each guard
            $adminRole->syncPermissions(Permission::where('guard_name', $guard)->pluck('name')->toArray());
        }
    }
}
