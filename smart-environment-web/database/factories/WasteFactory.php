<?php

namespace Database\Factories;

use App\Models\Waste;
use Illuminate\Database\Eloquent\Factories\Factory;

class WasteFactory extends Factory
{
    protected $model = Waste::class;

    public function definition(): array
    {
        return [
            'code' => 'WST-' . fake()->unique()->numerify('###'),
            'category' => 'inorganic',
            'name' => 'Sampah ' . fake()->word(),
            'description' => fake()->sentence(),
        ];
    }
}
