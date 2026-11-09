import urllib.request
import urllib.error
import json

token = '16|Ryu7a3isTC7Iv05b2poXySzAAMLZ8K7RIUTM3mpr500b0305'
url = 'https://bersihinapps-api-iti-2026.azurewebsites.net/api/v1/mobile/collector/off-schedule-pickups/1/complete'

for size_kb in [10, 100, 500, 1024, 2048, 4096]:
    dummy_photo = 'A' * (size_kb * 1024)
    payload = {
        'photo': dummy_photo,
        'waste_items': [{'waste_id': 1, 'pocket_size_id': 1, 'quantity': 1}]
    }
    try:
        req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': f'Bearer {token}',
            'Origin': 'https://witty-moss-04d728700.6.azurestaticapps.net'
        }, method='PUT')
        res = urllib.request.urlopen(req)
        print(f'{size_kb}KB: Success {res.status}')
    except urllib.error.HTTPError as e:
        cors = e.headers.get('Access-Control-Allow-Origin')
        body = e.read().decode('utf-8', errors='ignore')[:300]
        print(f'{size_kb}KB: HTTPError {e.code} | CORS: {cors} | Body: {body}')
    except Exception as ex:
        print(f'{size_kb}KB: General Error {type(ex)}: {ex}')
