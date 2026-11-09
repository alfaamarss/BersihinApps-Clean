import urllib.request
import urllib.error
import json

base_url = "https://bersihinapps-api-iti-2026.azurewebsites.net/api/v1"

def api_call(path, method="GET", payload=None, token=None):
    url = f"{base_url}{path}"
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Origin": "https://witty-moss-04d728700.6.azurestaticapps.net"
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(payload).encode("utf-8") if payload else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, resp.headers.get("Access-Control-Allow-Origin"), json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        try:
            body_json = json.loads(body)
        except:
            body_json = body
        return e.code, e.headers.get("Access-Control-Allow-Origin"), body_json
    except Exception as ex:
        return 0, None, str(ex)

print("--- Testing Azure Backend API ---")

# 1. Login Collector
status, cors, data = api_call("/auth/login", "POST", {
    "email": "collector@example.com",
    "password": "password",
    "device_name": "test"
})
print(f"Login Collector: {status} (CORS: {cors})")
collector_token = data.get("data", {}).get("token") if status == 200 else None

# 2. Login Resident
status, cors, data = api_call("/auth/login", "POST", {
    "email": "warga@example.com",
    "password": "password",
    "device_name": "test"
})
print(f"Login Resident: {status} (CORS: {cors})")
resident_token = data.get("data", {}).get("token") if status == 200 else None

# 3. Check collector off-schedule pickups
if collector_token:
    status, cors, data = api_call("/mobile/collector/off-schedule-pickups", "GET", token=collector_token)
    print(f"Collector Off-Schedule Pickups: {status} (CORS: {cors}) - count: {len(data.get('data', [])) if status == 200 else 'error'}")
    
    status, cors, data = api_call("/mobile/collector/off-schedule-pickups/waste-options", "GET", token=collector_token)
    print(f"Collector Waste Options: {status} (CORS: {cors})")
    
# 4. Check collector regular pickups
if collector_token:
    status, cors, data = api_call("/mobile/collector/today-pickups", "GET", token=collector_token)
    print(f"Collector Today Regular Pickups: {status} (CORS: {cors})")

# 5. Check resident dashboard
if resident_token:
    status, cors, data = api_call("/mobile/dashboard", "GET", token=resident_token)
    print(f"Resident Dashboard (BUG-003 check): {status} (CORS: {cors})")

# 6. Check articles
status, cors, data = api_call("/articles", "GET")
print(f"Public Articles: {status} (CORS: {cors}) - count: {len(data.get('data', [])) if status == 200 else 'error'}")
