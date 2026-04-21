import json
from firebase_admin import firestore
from firebase_functions import https_fn

@https_fn.on_request()
def update_doctor_location(req: https_fn.Request):
    # Only allow POST
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    db = firestore.client()

    # Parse request body
    body = req.get_json()
    doctor_id = body.get("doctorId")
    lat = body.get("lat")
    lng = body.get("lng")

    # Validate inputs
    if not doctor_id:
        return https_fn.Response("doctorId is required", status=400)
    if lat is None or lng is None:
        return https_fn.Response("lat and lng are required", status=400)

    # Update live location in Firestore
    db.collection("doctor_locations").document(doctor_id).set({
        "doctorId": doctor_id,
        "lat": lat,
        "lng": lng,
        "updated_at": firestore.SERVER_TIMESTAMP
    })

    return https_fn.Response(
        json.dumps({
            "success": True,
            "message": "Location updated"
        }),
        status=200,
        content_type="application/json"
    )


@https_fn.on_request()
def submit_report(req: https_fn.Request):
    # Only allow POST
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    db = firestore.client()

    body = req.get_json()
    incident_id = body.get("incidentId")
    doctor_id = body.get("doctorId")
    vitals = body.get("vitals")        # e.g. { pulse, bp, temperature }
    notes = body.get("notes")

    if not incident_id or not doctor_id:
        return https_fn.Response("incidentId and doctorId are required", status=400)

    # Save report to Firestore
    db.collection("reports").document(incident_id).set({
        "incident_id": incident_id,
        "doctor_id": doctor_id,
        "vitals": vitals,
        "notes": notes,
        "submitted_at": firestore.SERVER_TIMESTAMP
    })

    # Also update the incident doc to mark report submitted
    db.collection("incidents").document(incident_id).update({
        "report_submitted": True
    })

    return https_fn.Response(
        json.dumps({
            "success": True,
            "message": "Report submitted successfully"
        }),
        status=200,
        content_type="application/json"
    )