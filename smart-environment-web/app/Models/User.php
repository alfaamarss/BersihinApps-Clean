<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Spatie\Permission\Traits\HasRoles;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable, HasRoles, HasApiTokens, SoftDeletes;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'email_verified_at',
        'avatar_url',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    // Use default guard for web; Sanctum handles API auth

    public function serviceAccounts()
    {
        return $this->hasMany(ServiceAccount::class);
    }

    public function wasteDeliveries()
    {
        return $this->hasManyThrough(WasteDelivery::class, ServiceAccount::class);
    }

    public function invoices()
    {
        return $this->hasManyThrough(Invoice::class, ServiceAccount::class);
    }

    /**
     * Get complaints created by this user
     */
    public function complaints()
    {
        return $this->hasMany(Complaint::class);
    }

    /**
     * Get complaints assigned to this user (as assignee)
     */
    public function assignedComplaints()
    {
        return $this->hasMany(Complaint::class, 'assignee_id');
    }

    /**
     * Get TPS (garbage dumps) assigned to this collector
     */
    public function assignedTps()
    {
        return $this->belongsToMany(GarbageDump::class, 'garbage_dump_collector', 'collector_id', 'garbage_dump_id')
            ->withTimestamps();
    }
}
