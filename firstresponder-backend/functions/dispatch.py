import math
import firebase_admin
from firebase_admin import firestore
from firebase_functions import firestore_fn
import requests
import os

def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = math.sin(d_lat/2)**2 + math.cos(math.radians(lat1)) \
        * math.cos(math.radians(lat2)) * math.sin(d_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

@firestore_fn.on_document_created(document="incidents/{incidentId}")
def on_incident_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]):
    db = firestore.client()
    
    incident_data = event.data.to_dict()
    incident_lat = incident_data.get("lat")
    incident_lng = incident_data.get("lng")
    incident_id = event.params["incidentId"]
    
    # Get all approved + on-duty doctors
    doctors_ref = db.collection("doctors")
    doctors = doctors_ref.where("is_approved", "==", True).where("is_on_duty", "==", True).stream()
    
    nearby_doctors = []
    
    for doctor in doctors:
        doc = doctor.to_dict()
        doc_lat = doc.get("current_lat")
        doc_lng = doc.get("current_lng")
        
        if doc_lat and doc_lng:
            distance = haversine(incident_lat, incident_lng, doc_lat, doc_lng)
            if distance <= 2.0:
                nearby_doctors.append({
                    "doctorId": doctor.id,
                    "fcm_token": doc.get("fcm_token"),
                    "distance": round(distance, 2)
                })
    
    # Send FCM alert to all nearby doctors
    fcm_tokens = [d["fcm_token"] for d in nearby_doctors if d["fcm_token"]]
    
    if fcm_tokens:
        send_fcm_multicast(fcm_tokens, incident_id, incident_data)
    
    # Log dispatch
    db.collection("dispatch_log").document(incident_id).set({
        "incident_id": incident_id,
        "address": incident_data.get("address"),
        "emergency_type": incident_data.get("emergency_type"),
        "lat": incident_data.get("lat"),
        "lng": incident_data.get("lng"),
        "bystander_phone": incident_data.get("bystander_phone"),
        "doctors_alerted": nearby_doctors,
        "alerted_at": firestore.SERVER_TIMESTAMP
    })

def send_fcm_multicast(tokens, incident_id, incident_data):
    import google.auth
    import google.auth.transport.requests
    
    # Get access token
    credentials, project = google.auth.default(
        scopes=['https://www.googleapis.com/auth/firebase.messaging']
    )
    credentials.refresh(google.auth.transport.requests.Request())
    access_token = credentials.token
    
    # Send to each token
    for token in tokens:
        url = f"https://fcm.googleapis.com/v1/projects/first-responder-network/messages:send"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        payload = {
            "message": {
                "token": token,
                "notification": {
                    "title": "🚨 Emergency Alert",
                    "body": f"Emergency nearby: {incident_data.get('emergency_type', 'Unknown')}"
                },
                "data": {
                    "incident_id": incident_id,
                    "lat": str(incident_data.get("lat")),
                    "lng": str(incident_data.get("lng")),
                    "emergency_type": incident_data.get("emergency_type", ""),
                    "bystander_phone": incident_data.get("bystander_phone", "")
                },
                "android": {
                    "priority": "high"
                }
            }
        }
        requests.post(url, json=payload, headers=headers)