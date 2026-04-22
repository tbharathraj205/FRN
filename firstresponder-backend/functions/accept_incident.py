import math
from firebase_admin import firestore
from firebase_functions import https_fn
from flask import Request

def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance between two points using Haversine formula (in km)"""
    R = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = math.sin(d_lat/2)**2 + math.cos(math.radians(lat1)) \
        * math.cos(math.radians(lat2)) * math.sin(d_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

@https_fn.on_request()
def accept_incident_handler(req: Request):
    """Handle incident acceptance with closest doctor priority"""
    db = firestore.client()
    
    try:
        request_json = req.get_json()
        doctor_id = request_json.get('doctorId')
        incident_id = request_json.get('incidentId')
        
        if not doctor_id or not incident_id:
            return https_fn.Response(
                {'success': False, 'error': 'Missing doctorId or incidentId'},
                status=400,
                mimetype='application/json'
            )
        
        # Get incident
        incident_doc = db.collection('incidents').document(incident_id).get()
        if not incident_doc.exists:
            return https_fn.Response(
                {'success': False, 'error': 'Incident not found'},
                status=404,
                mimetype='application/json'
            )
        
        incident = incident_doc.to_dict()
        incident_lat = incident.get('lat')
        incident_lng = incident.get('lng')
        
        # If already accepted by someone, we need to compare distances
        if incident.get('assigned_doctor_id') and incident.get('status') == 'accepted':
            existing_doctor_id = incident.get('assigned_doctor_id')
            
            # Get existing doctor's location
            existing_doctor_doc = db.collection('doctors').document(existing_doctor_id).get()
            if not existing_doctor_doc.exists:
                return https_fn.Response(
                    {'success': False, 'error': 'Existing doctor not found'},
                    status=404,
                    mimetype='application/json'
                )
            
            existing_doctor = existing_doctor_doc.to_dict()
            existing_lat = existing_doctor.get('current_lat', 0)
            existing_lng = existing_doctor.get('current_lng', 0)
            
            # Get requesting doctor's location
            requesting_doctor_doc = db.collection('doctors').document(doctor_id).get()
            if not requesting_doctor_doc.exists:
                return https_fn.Response(
                    {'success': False, 'error': 'Doctor not found'},
                    status=404,
                    mimetype='application/json'
                )
            
            requesting_doctor = requesting_doctor_doc.to_dict()
            requesting_lat = requesting_doctor.get('current_lat', 0)
            requesting_lng = requesting_doctor.get('current_lng', 0)
            
            # Calculate distances
            existing_distance = haversine(existing_lat, existing_lng, incident_lat, incident_lng)
            requesting_distance = haversine(requesting_lat, requesting_lng, incident_lat, incident_lng)
            
            # Assign to closer doctor
            if requesting_distance < existing_distance:
                # New doctor is closer - reassign
                closer_doctor_id = doctor_id
                replaced_doctor_id = existing_doctor_id
            else:
                # Existing doctor is closer or same distance - keep existing
                return https_fn.Response(
                    {
                        'success': False,
                        'error': 'Another doctor is closer to the incident',
                        'assigned_to': existing_doctor_id,
                        'your_distance': round(requesting_distance, 2),
                        'closer_doctor_distance': round(existing_distance, 2)
                    },
                    status=409,
                    mimetype='application/json'
                )
        else:
            # No one has accepted yet
            closer_doctor_id = doctor_id
            replaced_doctor_id = None
        
        # Update incident
        db.collection('incidents').document(incident_id).update({
            'status': 'accepted',
            'assigned_doctor_id': closer_doctor_id,
        })
        
        # Mark doctor as busy
        db.collection('doctors').document(closer_doctor_id).update({
            'current_incident': incident_id
        })
        
        # If we're replacing another doctor, mark them as available again
        if replaced_doctor_id:
            db.collection('doctors').document(replaced_doctor_id).update({
                'current_incident': None
            })
        
        return https_fn.Response(
            {
                'success': True,
                'assigned_doctor_id': closer_doctor_id,
                'incident_id': incident_id
            },
            status=200,
            mimetype='application/json'
        )
        
    except Exception as e:
        return https_fn.Response(
            {'success': False, 'error': str(e)},
            status=500,
            mimetype='application/json'
        )

