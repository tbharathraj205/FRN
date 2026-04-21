import os
import requests
from firebase_admin import firestore
from firebase_functions import firestore_fn


@firestore_fn.on_document_updated(document="incidents/{incidentId}")
def on_doctor_accepted(event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]]):
    db = firestore.client()

    before = event.data.before.to_dict()
    after = event.data.after.to_dict()

    # Only trigger when status changes TO "accepted"
    if before.get("status") == after.get("status"):
        return
    if after.get("status") != "accepted":
        return

    incident_id = event.params["incidentId"]
    doctor_id = after.get("assigned_doctor_id")
    bystander_phone = after.get("bystander_phone")

    # Get doctor details
    doctor_doc = db.collection("doctors").document(doctor_id).get()
    doctor = doctor_doc.to_dict()

    doctor_name = doctor.get("name", "A doctor")
    doctor_phone = doctor.get("phone", "")

    # Send SMS to bystander via MSG91
    if bystander_phone:
        send_sms(
            to=bystander_phone,
            message=f"Help is on the way! Dr. {doctor_name} has accepted your emergency and is heading to you. Contact: {doctor_phone}."
        )

    # Update incident with accepted_at timestamp
    db.collection("incidents").document(incident_id).update({
        "accepted_at": firestore.SERVER_TIMESTAMP
    })

    # Mark doctor as busy
    db.collection("doctors").document(doctor_id).update({
        "current_incident": incident_id
    })


@firestore_fn.on_document_updated(document="incidents/{incidentId}")
def on_incident_resolved(event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]]):
    db = firestore.client()

    before = event.data.before.to_dict()
    after = event.data.after.to_dict()

    # Only trigger when status changes TO "resolved"
    if before.get("status") == after.get("status"):
        return
    if after.get("status") != "resolved":
        return

    doctor_id = after.get("assigned_doctor_id")

    # Reset doctor back to on-duty
    if doctor_id:
        db.collection("doctors").document(doctor_id).update({
            "is_on_duty": True,
            "current_incident": None
        })

    # Save resolved timestamp
    incident_id = event.params["incidentId"]
    db.collection("incidents").document(incident_id).update({
        "resolved_at": firestore.SERVER_TIMESTAMP
    })


def send_sms(to, message):
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
                "message": message,
                "to": [to]
            }
        ]
    }

    requests.post(url, json=payload, headers=headers)