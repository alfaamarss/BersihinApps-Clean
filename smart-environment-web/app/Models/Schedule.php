<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Schedule extends Model
{
    use HasFactory;

    protected $fillable = [
        'area_id',
        'day_of_week',
        'pickup_time',
        'is_active',
        'auto_generate_delivery',
        'generate_days_ahead'
    ];

    protected $casts = [
        'pickup_time' => 'datetime:H:i:s',
        'is_active' => 'boolean',
        'auto_generate_delivery' => 'boolean',
    ];

    public function setDayOfWeekAttribute($value)
    {
        $this->attributes['day_of_week'] = ucfirst(strtolower($value));
    }

    public function area()
    {
        return $this->belongsTo(Area::class);
    }

    public function collectorAssignments()
    {
        return $this->hasMany(CollectorAssignment::class);
    }

    public function wasteDeliveries()
    {
        return $this->hasMany(WasteDelivery::class);
    }
}
