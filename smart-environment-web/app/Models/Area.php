<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Area extends Model
{
    use HasFactory;

    protected $fillable = ['parent_id','name','level'];

    public function setLevelAttribute($value)
    {
        $this->attributes['level'] = ucfirst(strtolower($value));
    }

    public function parent()
    {
        return $this->belongsTo(Area::class, 'parent_id');
    }

    public function children()
    {
        return $this->hasMany(Area::class, 'parent_id');
    }

    public function schedules()
    {
        return $this->hasMany(Schedule::class);
    }

    public function serviceAccounts()
    {
        return $this->hasMany(ServiceAccount::class);
    }

    public function rws()
    {
        return $this->hasMany(Rw::class, 'kelurahan_id');
    }
}
