<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class WasteDelivery extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'service_account_id',
        'schedule_id',
        'pickup_date',
        'pickup_type',
        'request_status',
        'requested_at',
        'requested_pickup_date',
        'requested_pickup_time',
        'requested_by',
        'assigned_collector_id',
        'rejection_reason',
        'bag_count',
        'unit_price_snapshot',
        'base_amount',
        'extra_fee',
        'scheduled_at',
        'status',
        'confirmation_status',
        'confirmed_at',
        'collected_at',
        'completed_at',
        'resident_note',
        'collector_notes',
        'photo_url',
        'total_amount'
    ];

    protected $casts = [
        'pickup_date' => 'date',
        'scheduled_at' => 'datetime',
        'requested_at' => 'datetime',
        'requested_pickup_date' => 'date',
        'requested_pickup_time' => 'string',
        'confirmed_at' => 'datetime',
        'collected_at' => 'datetime',
        'completed_at' => 'datetime',
        'unit_price_snapshot' => 'float',
        'base_amount' => 'float',
        'extra_fee' => 'float',
        'bag_count' => 'integer',
        'total_amount' => 'float',
    ];

    // Relations
    public function serviceAccount()
    {
        return $this->belongsTo(ServiceAccount::class);
    }

    public function schedule()
    {
        return $this->belongsTo(Schedule::class);
    }

    public function wasteDeliveryItems()
    {
        return $this->hasMany(WasteDeliveryItem::class);
    }

    public function invoice()
    {
        return $this->hasOne(Invoice::class);
    }

    public function requestedBy()
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    public function assignedCollector()
    {
        return $this->belongsTo(User::class, 'assigned_collector_id');
    }

    // Accessor untuk mendapatkan collector dari schedule assignment
    public function getCollectorAttribute()
    {
        if (!$this->schedule) {
            return null;
        }

        $assignment = $this->schedule
            ->collectorAssignments()
            ->where('start_date', '<=', $this->pickup_date)
            ->where(function($q) {
                $q->whereNull('end_date')
                  ->orWhere('end_date', '>=', $this->pickup_date);
            })
            ->with('user')
            ->first();

        return $assignment?->user;
    }

    // Helper method untuk get collector_id
    public function getCollectorIdAttribute()
    {
        return $this->collector?->id;
    }

    /**
     * Get clean, valid full URL for photo evidence
     */
    public function getPhotoDisplayUrlAttribute(): ?string
    {
        if (empty($this->photo_url)) {
            return null;
        }

        if (str_starts_with($this->photo_url, 'http://') || str_starts_with($this->photo_url, 'https://')) {
            return $this->photo_url;
        }

        $cleanPath = ltrim(preg_replace('#^/?storage/#', '', $this->photo_url), '/');
        return asset('storage/' . $cleanPath);
    }
}
