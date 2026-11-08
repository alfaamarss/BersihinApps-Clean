<!doctype html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="h-full">

<head>
    <meta charset="UTF-8" />
    <meta name="viewport"
        content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0" />
    <meta http-equiv="X-UA-Compatible" content="ie=edge" />
    <title>@yield('title', 'Dashboard') | {{ isset($appSettings) ? $appSettings->app_name : config('app.name', 'TailAdmin') }}</title>
    <meta name="csrf-token" content="{{ csrf_token() }}" />
    @stack('head:before')
    @vite(['resources/css/app.css', 'resources/js/index.js'])
    <!-- SweetAlert2 -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script>
        window.APP = {
            apiBase: '{{ url('/api/v1') }}',
            // Optional: if you store a token for server->API calls, set here.
            token: null,
        };
    </script>
    <link href="{{ asset('assets/images/logo/beresin-icon.png') }}" rel="icon">
    @stack('styles')
    @stack('head:after')
</head>

<body x-data="{ page: 'ecommerce', loaded: true, darkMode: false, stickyMenu: false, sidebarToggle: false, scrollTop: false }"
      x-init="darkMode = JSON.parse(localStorage.getItem('darkMode')) ?? false; $watch('darkMode', v => localStorage.setItem('darkMode', JSON.stringify(v)))"
      :class="{ 'dark bg-gray-900': darkMode === true }" class="min-h-full">
    <!-- ===== Preloader Start ===== -->
    @include('partials.preloader')
    <!-- ===== Preloader End ===== -->

    <!-- ===== Page Wrapper Start ===== -->
    <div class="flex h-screen overflow-hidden">
        <!-- ===== Sidebar Start ===== -->
        {{-- <include src="./partials/sidebar.html"></include> --}}
        @include('layouts.sidebar')
        <!-- ===== Sidebar End ===== -->

        <!-- ===== Content Area Start ===== -->
        <div class="relative flex flex-col flex-1 overflow-x-hidden overflow-y-auto">
            <!-- Small Device Overlay Start -->
            @include('partials.overlay')
            <!-- Small Device Overlay End -->

            <!-- ===== Header Start ===== -->
            {{-- <include src="./partials/header.html" /> --}}
            @include('layouts.header')

            <!-- ===== Header End ===== -->

            <!-- ===== Main Content Start ===== -->
            <main>
                <div class="p-4 mx-auto max-w-(--breakpoint-2xl) md:p-6">
                    @include('partials.flash')
                    @hasSection('content')
                        @yield('content')
                    @else
                        <div class="grid grid-cols-12 gap-4 md:gap-6">
                            <div class="col-span-12 space-y-6 xl:col-span-7">
                                @include('partials.metric-group.metric-group-01')
                                @include('partials.chart.chart-01')
                            </div>
                            <div class="col-span-12 xl:col-span-5">
                                @include('partials.chart.chart-02')
                            </div>
                            <div class="col-span-12">
                                @include('partials.chart.chart-03')
                            </div>
                            <div class="col-span-12 xl:col-span-5">
                                @include('partials.map-01')
                            </div>
                            <div class="col-span-12 xl:col-span-7">
                                @include('partials.table.table-01')
                            </div>
                        </div>
                    @endif
                </div>
            </main>
            <!-- ===== Main Content End ===== -->
        </div>
        <!-- ===== Content Area End ===== -->
    </div>
    <!-- ===== Page Wrapper End ===== -->
    
    <!-- Notification Script -->
    @include('partials.notification-script')
    
    @stack('scripts')
    @stack('body:end')
</body>

</html>
