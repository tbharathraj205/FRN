import requests
import json
import os
from firebase_functions import https_fn

# Get API key from environment, fallback to hardcoded value
GOOGLE_MAPS_API_KEY = os.environ.get('GOOGLE_MAPS_API_KEY', 'AIzaSyAWEw5188AQlG7CLaGNTb4Irf00ypf9qQw')


@https_fn.on_request()
def get_route(req: https_fn.Request):
    """
    Get route directions between two points using Google Maps Directions API
    
    Query Parameters:
    - fromLat: Origin latitude
    - fromLng: Origin longitude
    - toLat: Destination latitude
    - toLng: Destination longitude
    """
    
    # Enable CORS
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json',
    }
    
    if req.method == 'OPTIONS':
        return https_fn.Response('', status=204, headers=headers)
    
    try:
        # Get coordinates from query parameters
        from_lat = req.args.get('fromLat')
        from_lng = req.args.get('fromLng')
        to_lat = req.args.get('toLat')
        to_lng = req.args.get('toLng')
        
        # Debug: log received parameters
        print(f"Received params - fromLat: {from_lat}, fromLng: {from_lng}, toLat: {to_lat}, toLng: {to_lng}")
        
        # Validate parameters
        if not all([from_lat, from_lng, to_lat, to_lng]):
            return https_fn.Response(
                json.dumps({
                    'error': 'Missing required parameters: fromLat, fromLng, toLat, toLng',
                    'received': {'fromLat': from_lat, 'fromLng': from_lng, 'toLat': to_lat, 'toLng': to_lng}
                }),
                status=400,
                headers=headers
            )
        
        # Check if API key is set
        if not GOOGLE_MAPS_API_KEY:
            return https_fn.Response(
                json.dumps({
                    'error': 'Google Maps API key not configured in environment',
                    'success': False
                }),
                status=500,
                headers=headers
            )
        
        # Build Google Maps Directions API request
        url = 'https://maps.googleapis.com/maps/api/directions/json'
        params = {
            'origin': f'{from_lat},{from_lng}',
            'destination': f'{to_lat},{to_lng}',
            'key': GOOGLE_MAPS_API_KEY,
            'mode': 'driving'
        }
        
        # Call Google Maps API
        response = requests.get(url, params=params)
        data = response.json()
        
        print(f"Google Maps API response status: {data.get('status')}")
        
        if data['status'] != 'OK':
            return https_fn.Response(
                json.dumps({
                    'error': f'Google Maps API error: {data["status"]}',
                    'message': data.get('error_message', 'Unknown error'),
                    'success': False
                }),
                status=400,
                headers=headers
            )
        
        # Extract polyline and distance info
        if not data.get('routes'):
            return https_fn.Response(
                json.dumps({
                    'error': 'No route found',
                    'success': False
                }),
                status=400,
                headers=headers
            )
        
        route = data['routes'][0]
        polyline = route.get('overview_polyline', {}).get('points', '')
        distance = route['legs'][0].get('distance', {}).get('value', 0)  # meters
        duration = route['legs'][0].get('duration', {}).get('value', 0)  # seconds
        
        return https_fn.Response(
            json.dumps({
                'success': True,
                'polyline': polyline,
                'distance': distance,  # in meters
                'distanceKm': distance / 1000,
                'duration': duration,  # in seconds
                'durationMinutes': duration / 60
            }),
            status=200,
            headers=headers
        )
        
    except Exception as e:
        return https_fn.Response(
            json.dumps({
                'error': str(e)
            }),
            status=500,
            headers=headers
        )
