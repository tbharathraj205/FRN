import firebase_admin
from firebase_admin import firestore

# Initialize Firebase Admin once
firebase_admin.initialize_app()

# Import and explicitly export all functions
from dispatch import on_incident_created
from incidents import on_doctor_accepted, on_incident_resolved
from notifications import approve_doctor
from reports import update_doctor_location, submit_report

# Explicitly expose them at module level
__all__ = [
    "on_incident_created",
    "on_doctor_accepted", 
    "on_incident_resolved",
    "approve_doctor",
    "update_doctor_location",
    "submit_report"
]