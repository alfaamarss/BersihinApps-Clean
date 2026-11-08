<aside :class="sidebarToggle ? 'translate-x-0 lg:w-[90px]' : '-translate-x-full'"
       class="sidebar fixed left-0 top-0 z-9998 flex h-screen w-[290px] flex-col overflow-y-hidden border-r border-gray-200 bg-white px-5 duration-300 ease-linear dark:border-gray-800 dark:bg-black lg:static lg:translate-x-0"
       @click.outside="sidebarToggle = false">
  <div :class="sidebarToggle ? 'justify-center' : 'justify-between'" class="sidebar-header flex items-center gap-2 pb-7 pt-8">
    @php
      $resolvedLogo = null;
      if(isset($appSettings) && $appSettings->app_logo_url &&
         $appSettings->app_logo_url !== 'storage/' &&
         $appSettings->app_logo_url !== 'storage') {
        $resolvedLogo = \Illuminate\Support\Str::startsWith($appSettings->app_logo_url, ['http://', 'https://'])
          ? $appSettings->app_logo_url
          : asset($appSettings->app_logo_url);
      }
    @endphp

    <a href="{{ route('home') }}" class="flex items-center gap-3">
      <span class="logo" :class="sidebarToggle ? 'hidden' : ''">
        @if($resolvedLogo)
          <img class="h-11 w-auto max-w-[190px] object-contain" src="{{ $resolvedLogo }}" alt="{{ $appSettings->app_name }}" />
        @else
          <img class="dark:hidden h-11 w-auto max-w-[190px] object-contain" src="{{ asset('assets/images/logo/beresin.png') }}" alt="Beresin" />
          <img class="hidden dark:block h-11 w-auto max-w-[190px] object-contain" src="{{ asset('assets/images/logo/beresin-dark.png') }}" alt="Beresin" />
        @endif
      </span>

      <img class="logo-icon h-10 w-10 object-contain"
           :class="sidebarToggle ? 'lg:block' : 'hidden'"
           src="{{ asset('assets/images/logo/beresin-icon.png') }}"
           alt="{{ isset($appSettings) ? $appSettings->app_name : 'Beresin' }}" />
    </a>
  </div>

  <div class="no-scrollbar flex flex-col overflow-y-auto duration-300 ease-linear">
    @auth
    @if(!empty($menuTree) && count($menuTree))
    @php
      // Closure sederhana untuk cek apakah url menu aktif dibandingkan request saat ini
      $checkActive = function($url) {
          if(!$url) return false;
          $path = ltrim(parse_url($url, PHP_URL_PATH), '/');
          if($path === '') return false;
          
          // Fix specific conflict: admin/schedules vs admin/schedules/calendar
          // If we are checking 'admin/schedules' but the current request is 'admin/schedules/calendar', return false
          if ($path === 'admin/schedules' && request()->is('admin/schedules/calendar*')) {
              return false;
          }

          return request()->is($path) || request()->is($path.'/*');
      };
    @endphp
    <nav x-data="{ open: {} }" class="mb-6">
      @foreach($menuTree as $group)
        @php($g = $group['menu'])
        <div class="mt-2">
          <h3 class="mb-4 text-xs uppercase leading-[20px] text-gray-400">
            <span class="menu-group-title" :class="sidebarToggle ? 'lg:hidden' : ''">{{ strtoupper($g->nama_menu) }}</span>
            @php($groupIcon = $g->icon)
            @if($groupIcon)
              <i :class="sidebarToggle ? 'lg:block hidden' : 'hidden'" class="menu-group-icon mx-auto text-[18px] {{$groupIcon}}"></i>
            @else
              <svg :class="sidebarToggle ? 'lg:block hidden' : 'hidden'" class="menu-group-icon mx-auto fill-current" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" clip-rule="evenodd" d="M5.999 10.245c.966 0 1.75.783 1.75 1.75v.01c0 .967-.784 1.75-1.75 1.75s-1.75-.783-1.75-1.75v-.01c0-.967.784-1.75 1.75-1.75Zm12 0c.967 0 1.75.783 1.75 1.75v.01c0 .967-.783 1.75-1.75 1.75s-1.75-.783-1.75-1.75v-.01c0-.967.783-1.75 1.75-1.75ZM13.75 11.995c0-.967-.784-1.75-1.75-1.75s-1.75.783-1.75 1.75v.01c0 .967.784 1.75 1.75 1.75s1.75-.783 1.75-1.75v-.01Z"/></svg>
            @endif
          </h3>
          <ul class="flex flex-col gap-2">
            @foreach(($group['children'] ?? []) as $childNode)
              @php($c = $childNode['menu'])
              @php($grand = $childNode['children'] ?? collect())
              @php($selfActive = $checkActive($c->url))
              @php($anyGrandActive = $grand->contains(function($gch) use ($checkActive){ return $checkActive($gch->url); }))
              @php($childActive = $selfActive || $anyGrandActive)
              @if($grand && count($grand))
                <li @if($childActive) x-init="open['c{{ $c->id }}']=true" @endif>
                  <a href="#" @click.prevent="open['c{{ $c->id }}'] = !open['c{{ $c->id }}']" class="menu-item group" :class="open['c{{ $c->id }}'] ? 'menu-item-active' : 'menu-item-inactive'">
                    @php($icon = $c->icon)
                    @if($icon)
                      <i class="{{ $childActive ? 'menu-item-icon-active' : 'menu-item-icon-inactive' }} text-[18px] {{$icon}}"></i>
                    @else
                      <svg class="{{ $childActive ? 'menu-item-icon-active' : 'menu-item-icon-inactive' }}" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C13.1046 2 14 2.89543 14 4V5H16C17.1046 5 18 5.89543 18 7V19C18 20.1046 17.1046 21 16 21H8C6.89543 21 6 20.1046 6 19V7C6 5.89543 6.89543 5 8 5H10V4C10 2.89543 10.8954 2 12 2ZM12 4V5H10V4C10 3.44772 10.4477 3 11 3H13C13.5523 3 14 3.44772 14 4V5H12ZM8 7V19H16V7H8Z" fill=""/></svg>
                    @endif
                    <span class="menu-item-text" :class="sidebarToggle ? 'lg:hidden' : ''">{{ $c->nama_menu }}</span>
                    <svg class="menu-item-arrow" :class="[open['c{{ $c->id }}'] ? 'menu-item-arrow-active' : 'menu-item-arrow-inactive', sidebarToggle ? 'lg:hidden' : '']" width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4.792 7.396 10 12.604 15.208 7.396" stroke="" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  </a>
                  <div class="translate transform overflow-hidden" :class="open['c{{ $c->id }}'] ? 'block' : 'hidden'">
                    <ul :class="sidebarToggle ? 'lg:hidden' : 'flex'" class="menu-dropdown mt-2 flex flex-col gap-1 pl-9">
                      @foreach($grand as $gch)
                        @php($grandActive = $checkActive($gch->url))
                        <li>
                          <a href="{{ $gch->url ? (\Illuminate\Support\Str::startsWith($gch->url, ['http://','https://','/']) ? $gch->url : url($gch->url)) : '#' }}" class="menu-dropdown-item group {{ $grandActive ? 'menu-dropdown-item-active' : 'menu-dropdown-item-inactive' }}">{{ $gch->nama_menu }}</a>
                        </li>
                      @endforeach
                    </ul>
                  </div>
                </li>
              @else
                <li>
                  @php($isActive = $childActive)
                  <a href="{{ $c->url ? (\Illuminate\Support\Str::startsWith($c->url, ['http://','https://','/']) ? $c->url : url($c->url)) : '#' }}" class="menu-item group {{ $isActive ? 'menu-item-active' : 'menu-item-inactive' }}">
                    @php($icon = $c->icon)
                    @if($icon)
                      <i class="{{ $isActive ? 'menu-item-icon-active' : 'menu-item-icon-inactive' }} text-[18px] {{$icon}}"></i>
                    @else
                      <svg class="{{ $isActive ? 'menu-item-icon-active' : 'menu-item-icon-inactive' }}" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="4" stroke="currentColor" stroke-width="1.5"/></svg>
                    @endif
                    <span class="menu-item-text" :class="sidebarToggle ? 'lg:hidden' : ''">{{ $c->nama_menu }}</span>
                  </a>
                </li>
              @endif
            @endforeach
          </ul>
        </div>
      @endforeach
    </nav>
    @endif
    @endauth
  </div>
</aside>
