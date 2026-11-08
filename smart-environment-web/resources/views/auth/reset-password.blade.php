<!doctype html>
<html lang="en">

<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="X-UA-Compatible" content="ie=edge" />
    <title>Reset Password | {{ isset($appSettings) ? $appSettings->app_name : config('app.name', 'Bersihin') }}</title>
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

            <!-- Reset Password Card -->
            <div class="rounded-2xl bg-white/95 p-8 shadow-2xl ring-1 ring-white/10 backdrop-blur-md dark:bg-gray-900/95">
                <div class="mb-6 text-center">
                    <h2 class="text-2xl font-semibold text-gray-900 dark:text-white">Set New Password</h2>
                    <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">Create a new password for your account</p>
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

                <form action="{{ route('password.update') }}" method="POST" class="space-y-5">
                    @csrf
                    <input type="hidden" name="token" value="{{ $token }}">
                    <input type="hidden" name="email" value="{{ request()->email }}">

                    <!-- Email Field (Readonly) -->
                    <div>
                        <label class="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Email Address</label>
                        <div class="relative">
                            <input type="email" value="{{ request()->email }}" disabled
                                   class="peer w-full rounded-lg border border-gray-300 bg-gray-100 px-4 py-3 pl-11 text-gray-500 outline-none cursor-not-allowed dark:border-gray-700 dark:bg-gray-800 dark:text-gray-400">
                            <svg class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207"/>
                            </svg>
                        </div>
                    </div>

                    <!-- Password Field -->
                    <div>
                        <label class="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">New Password</label>
                        <div class="relative">
                            <input id="password" type="password" name="password" required
                                   class="peer w-full rounded-lg border border-gray-300 bg-white px-4 py-3 pl-11 pr-11 text-gray-900 outline-none transition focus:border-green-500 focus:ring-4 focus:ring-green-500/20 dark:border-gray-700 dark:bg-gray-800 dark:text-white dark:focus:border-green-400"
                                   placeholder="••••••••" />
                            <svg class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                            </svg>
                            <button type="button" onclick="const el=document.getElementById('password'); el.type = el.type==='password' ? 'text' : 'password'; this.querySelector('svg').classList.toggle('hidden'); this.querySelectorAll('svg')[1].classList.toggle('hidden');"
                                    class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300" aria-label="Toggle password">
                                <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.477 0 8.268 2.943 9.542 7-1.206 4.057-5.065 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                                </svg>
                                <svg class="h-5 w-5 hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>
                                </svg>
                            </button>
                        </div>
                    </div>

                    <!-- Confirm Password Field -->
                    <div>
                        <label class="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Confirm Password</label>
                        <div class="relative">
                            <input id="password_confirmation" type="password" name="password_confirmation" required
                                   class="peer w-full rounded-lg border border-gray-300 bg-white px-4 py-3 pl-11 pr-11 text-gray-900 outline-none transition focus:border-green-500 focus:ring-4 focus:ring-green-500/20 dark:border-gray-700 dark:bg-gray-800 dark:text-white dark:focus:border-green-400"
                                   placeholder="••••••••" />
                            <svg class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                            </svg>
                        </div>
                    </div>

                    <!-- Submit Button -->
                    <button type="submit" class="group relative inline-flex w-full items-center justify-center overflow-hidden rounded-lg bg-gradient-to-r from-green-600 to-emerald-600 px-6 py-3 font-semibold text-white shadow-lg transition hover:from-green-700 hover:to-emerald-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2">
                        <span class="absolute inset-0 h-full w-full translate-y-10 bg-gradient-to-t from-white/20 to-white/0 opacity-0 transition duration-300 ease-out group-hover:translate-y-0 group-hover:opacity-100"></span>
                        <svg class="mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                        <span class="relative">Reset Password</span>
                    </button>
                </form>
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
