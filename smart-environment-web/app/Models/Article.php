<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class Article extends Model
{
    use HasFactory;

    public const STATUSES = ['draft', 'published', 'archived'];

    protected $fillable = [
        'title',
        'slug',
        'summary',
        'content',
        'featured_image',
        'author',
        'published_at',
        'status',
    ];

    protected $casts = [
        'published_at' => 'datetime',
    ];

    protected static function boot()
    {
        parent::boot();

        // Delete image when article is deleted
        static::deleting(function ($article) {
            if ($article->featured_image && Storage::disk('public')->exists($article->featured_image)) {
                Storage::disk('public')->delete($article->featured_image);
            }
        });
    }

    /**
     * Get the full URL for the featured image.
     *
     * @return string|null
     */
    public function getFeaturedImageUrlAttribute()
    {
        if (!$this->featured_image) {
            return null;
        }

        if (str_starts_with($this->featured_image, 'http://') || str_starts_with($this->featured_image, 'https://')) {
            return $this->featured_image;
        }

        return asset('storage/' . ltrim($this->featured_image, '/'));
    }

    /**
     * Get estimated reading time in minutes.
     *
     * @return int
     */
    public function getEstimatedReadingTimeAttribute()
    {
        $wordCount = str_word_count(strip_tags($this->content));
        $minutes = ceil($wordCount / 200); // Assuming 200 words per minute
        return max(1, $minutes);
    }

    public static function generateUniqueSlug(?string $value, ?int $ignoreId = null): string
    {
        $base = Str::slug((string) $value);

        if ($base === '') {
            $base = 'artikel-' . Str::random(6);
        }

        $slug = $base;
        $counter = 2;

        while (
            static::query()
                ->when($ignoreId, fn($q) => $q->where('id', '!=', $ignoreId))
                ->where('slug', $slug)
                ->exists()
        ) {
            $slug = $base . '-' . $counter++;
        }

        return $slug;
    }
}
