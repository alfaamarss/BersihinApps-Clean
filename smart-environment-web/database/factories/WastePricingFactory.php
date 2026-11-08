<?php

namespace Database\Factories;

use App\Models\PocketSize;
use App\Models\Waste;
use App\Models\WastePricing;
use Illuminate\Database\Eloquent\Factories\Factory;

class WastePricingFactory extends Factory
{
    protected $model = WastePricing::class;

    public function definition(): array
    {
        return [
            'waste_id' => Waste::factory(),
            'pocket_size_id' => PocketSize::factory(),
            'price' => fake()->numberBetween(2000, 10000),
            'effective_from' => now()->subDays(30),
            'effective_to' => null,
        ];
    }
}
