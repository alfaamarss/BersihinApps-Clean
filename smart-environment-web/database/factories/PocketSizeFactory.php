<?php

namespace Database\Factories;

use App\Models\PocketSize;
use Illuminate\Database\Eloquent\Factories\Factory;

class PocketSizeFactory extends Factory
{
    protected $model = PocketSize::class;

    public function definition(): array
    {
        return [
            'name' => fake()->randomElement(['Kecil', 'Sedang', 'Besar']),
            'description' => fake()->sentence(),
        ];
    }
}
