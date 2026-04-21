import os
import requests
import json
from firebase_admin import firestore
from firebase_functions import https_fn


@https_fn.on_request()
def approve_doctor(req: https_fn.Request):
    # Only allow POST
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    db = firestore.client()

    # Parse request body
    body = req.get_json()
    doctor_id = body.get("doctorId")

    if not doctor_id:
        return https_fn.Response("doctorId is required", status=400)

    # Get doctor details first
    doctor_doc = db.collection("doctors").document(doctor_id).get()

    if not doctor_doc.exists:
        return https_fn.Response("Doctor not found", status=404)

    doctor = doctor_doc.to_dict()
    doctor_name = doctor.get("name", "Doctor")
    doctor_phone = doctor.get("phone")

    # Approve the doctor in Firestore
    db.collection("doctors").document(doctor_id).update({
        "is_approved": True,
        "approved_at": firestore.SERVER_TIMESTAMP
    })

    # Send welcome SMS to doctor via MSG91
    if doctor_phone:
        send_welcome_sms(doctor_phone, doctor_name)

    return https_fn.Response(
        json.dumps({
            "success": True,
            "message": f"Dr. {doctor_name} approved successfully"
        }),
        status=200,
        content_type="application/json"
    )


def send_welcome_sms(phone, name):
    MSG91_API_KEY = os.environ.get("MSG91_API_KEY")
    MSG91_SENDER_ID = os.environ.get("MSG91_SENDER_ID")

    url = "https://api.msg91.com/api/v5/flow/"
    headers = {
        "authkey": MSG91_API_KEY,
        "Content-Type": "application/json"
    }

    payload = {
        "sender": MSG91_SENDER_ID,
        "route": "4",
        "country": "91",
        "sms": [
            {
                "message": f"Welcome Dr. {name}! Your First Responder Network account has been approved. You can now go on-duty and respond to emergencies.",
                "to": [phone]
            }
        ]
    }

    requests.post(url, json=payload, headers=headers)