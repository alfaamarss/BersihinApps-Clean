<!doctype html>
<html lang="en">

<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="X-UA-Compatible" content="ie=edge" />
    <title>Forgot Password | {{ isset($appSettings) ? $appSettings->app_name : config('app.name', 'Bersihin') }}</title>
    <link href="https://cdn.tailwindcss.com" rel="stylesheet">
    <link href="{{ asset('assets/images/logo/beresin-icon.png') }}" rel="icon">
    <script src="https://cdn.tailwindcss.com"></script>
</head>

<body class="min-h-screen" style="background-color: #0b1f3a">
    <div class="relative flex min-h-screen items-center justify-center px-4 py-10">
        <!-- Decorative background elements with environmental theme -->
        <div class="absolute inset-0 overflow-hidden opacity-20">
            <svg class="absolute left-0 top-0 h-full w-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <pattern id="leaves" x="0" y="0" width="100" height="100" patternUnits="userSpaceOnUse">
                        <path d="M20 20c5-5 10-5 15 0s5 10 0 15-10 5-15 0-5-10 0-15z" fill="currentColor" fill-opacity="0.1" class="text-white"/>
                    </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#leaves)"/>
            </svg>
        </div>

        <div class="relative z-10 mx-auto w-full max-w-md">
            <!-- Logo and App Name from Database -->
            <div class="mb-8 flex items-center justify-center gap-4">
                @php
                    $logoUrl = null;
                    if(isset($appSettings) && $appSettings->app_logo_url &&
                       $appSettings->app_logo_url !== 'storage/' &&
                       $appSettings->app_logo_url !== 'storage') {
                        $logoUrl = \Illuminate\Support\Str::startsWith($appSettings->app_logo_url, ['http://', 'https://'])
                            ? $appSettings->app_logo_url
                            : asset($appSettings->app_logo_url);
                    }
                @endphp

                @if($logoUrl)
                    <img class="h-16 w-auto max-w-[220px] object-contain drop-shadow-lg bg-white px-3 py-1.5 rounded-xl" src="{{ $logoUrl }}" alt="Logo" />
                @else
                    <img class="h-16 w-auto max-w-[220px] object-contain drop-shadow-lg bg-white px-3 py-1.5 rounded-xl" src="{{ asset('assets/images/logo/beresin.png') }}" alt="Logo" />
                @endif

                <div class="text-white">
                    <h1 class="text-3xl font-bold leading-tight drop-shadow-md">
                        {{ isset($appSettings) ? $appSettings->app_name : config('app.name', 'Bersihin') }}
                    </h1>
                    <p class="text-white/90 text-base drop-shadow">Smart Environment System</p>
                </div>
            </div>

            <!-- Forgot Password Card -->
            <div class="rounded-2xl bg-white/95 p-8 shadow-2xl ring-1 ring-white/10 backdrop-blur-md dark:bg-gray-900/95">
                <div class="mb-6 text-center">
                    <h2 class="text-2xl font-semibold text-gray-900 dark:text-white">Reset Password</h2>
                    <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">Enter your email to receive a reset link</p>
                </div>

                @if (session('status'))
                    <div class="mb-4 rounded-lg border border-green-200 bg-green-50 p-3 text-sm text-green-700 dark:border-green-800 dark:bg-green-900/40 dark:text-green-200">
                        {{ session('status') }}
                    </div>
                @endif

                @if($errors->any())
                    <div class="mb-4 rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-800 dark:bg-red-900/40 dark:text-red-200">
                        <ul class="list-disc pl-5 space-y-1">
                            @foreach($errors->all() as $error)
                                <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif

                <form action="{{ route('password.email') }}" method="POST" class="space-y-5">
                    @csrf

                    <!-- Email Field -->
                    <div>
                        <label class="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Email Address</label>
                        <div class="relative">
                            <input type="email" name="email" value="{{ old('email') }}" required
                                   class="peer w-full rounded-lg border border-gray-300 bg-white px-4 py-3 pl-11 text-gray-900 outline-none transition focus:border-green-500 focus:ring-4 focus:ring-green-500/20 dark:border-gray-700 dark:bg-gray-800 dark:text-white dark:focus:border-green-400"
                                   placeholder="you@example.com">
                            <svg class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207"/>
                            </svg>
                        </div>
                    </div>

                    <!-- Submit Button -->
                    <button type="submit" class="group relative inline-flex w-full items-center justify-center overflow-hidden rounded-lg bg-gradient-to-r from-green-600 to-emerald-600 px-6 py-3 font-semibold text-white shadow-lg transition hover:from-green-700 hover:to-emerald-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2">
                        <span class="absolute inset-0 h-full w-full translate-y-10 bg-gradient-to-t from-white/20 to-white/0 opacity-0 transition duration-300 ease-out group-hover:translate-y-0 group-hover:opacity-100"></span>
                        <svg class="mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                        </svg>
                        <span class="relative">Send Reset Link</span>
                    </button>
                </form>

                <!-- Back to Login -->
                <div class="mt-6 text-center">
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                        Remember your password?
                        <a href="{{ route('login') }}" class="font-medium text-green-600 hover:text-green-700 dark:text-green-400 dark:hover:text-green-300">
                            Sign in
                        </a>
                    </p>
                </div>
            </div>

            <!-- Footer -->
            <p class="mt-6 text-center text-white/90 text-sm drop-shadow">
                <svg class="inline-block h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd"/>
                </svg>
                © {{ date('Y') }} {{ isset($appSettings) ? $appSettings->app_name : config('app.name', 'Bersihin') }}. All rights reserved.
            </p>
        </div>
    </div>
</body>

</html>
