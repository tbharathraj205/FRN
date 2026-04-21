# First Responder Network - Backend Functions API

## Overview

The First Responder Network backend is a Python-based Firebase Cloud Functions API that powers the emergency response coordination system. It manages incident dispatch, doctor notifications, SMS communications, location tracking, and medical report submissions.

**Technology Stack:**
- **Runtime:** Python 3.13
- **Platform:** Firebase Cloud Functions
- **Database:** Firestore
- **Messaging:** Firebase Cloud Messaging (FCM) + MSG91 SMS
- **Location Services:** Geolocation-based dispatch using Haversine distance calculations

---

## Project Structure

```
firstresponder-backend/
├── functions/
│   ├── main.py                 # Entry point - exports all functions
│   ├── dispatch.py             # Incident dispatch & doctor alerting
│   ├── incidents.py            # Incident status tracking
│   ├── notifications.py        # Doctor approval & SMS
│   ├── reports.py              # Location updates & medical reports
│   ├── requirements.txt         # Python dependencies
│ 
├── firebase.json               # Firebase configuration
└── README.md                   # This file
```

---

## Setup & Installation

### Prerequisites
- Python 3.13+
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase project with Firestore enabled
- MSG91 account for SMS functionality

### Local Development

1. **Install dependencies:**
   ```bash
   cd firstresponder-backend/functions
   pip install -r requirements.txt
   ```

2. **Set up environment variables:**
   Create a `.env` file or configure in Firebase:
   ```
   MSG91_API_KEY=your_msg91_api_key
   MSG91_SENDER_ID=your_sender_id
   GOOGLE_APPLICATION_CREDENTIALS=path/to/firebase-key.json
   ```

3. **Initialize Firebase locally:**
   ```bash
   firebase init
   firebase emulators:start
   ```

4. **Deploy functions:**
   ```bash
   firebase deploy --only functions
   ```

---

## API Functions Documentation

### 1. **on_incident_created** (Firestore Trigger)

**Trigger:** Document created in `incidents/{incidentId}`

**Purpose:** Automatically dispatches nearby doctors when an emergency incident is reported.

**Process Flow:**
1. Extracts incident location (lat, lng) and details from the created document
2. Queries Firestore for all doctors matching:
   - `is_approved == true`
   - `is_on_duty == true`
3. Calculates distance using Haversine formula (50km radius)
4. Sends FCM push notifications to nearby doctors with incident details
5. Logs dispatch activity to `dispatch_log` collection

**Input (Firestore Document):**
```json
{
  "lat": 12.9716,
  "lng": 77.5946,
  "emergency_type": "Heart Attack",
  "bystander_phone": "+91-9876543210"
}
```

**Output:**
- FCM notifications sent to nearby doctors
- Entry created in `dispatch_log` with doctor list and distance info
- Incident status remains "pending" until a doctor accepts

**Distance Calculation:** Uses Haversine formula (great-circle distance) with Earth radius = 6371 km

---

### 2. **on_doctor_accepted** (Firestore Trigger)

**Trigger:** Document updated in `incidents/{incidentId}` (status field changed)

**Purpose:** Notifies bystander when a doctor accepts the emergency and marks doctor as busy.

**Activation Condition:**
- Only triggers when status changes to `"accepted"`
- Compares `before.status != after.status`

**Process Flow:**
1. Verifies status changed to "accepted"
2. Retrieves doctor details from `doctors/{doctorId}`
3. Sends SMS to bystander phone with doctor name and contact
4. Updates incident with `accepted_at` timestamp
5. Marks doctor as busy by updating `current_incident`

**Input (Firestore Update):**
```json
{
  "status": "accepted",
  "assigned_doctor_id": "doc123",
  "bystander_phone": "+91-9876543210"
}
```

**SMS Message Format:**
```
Help is on the way! Dr. [Name] has accepted your emergency and is heading to you. Contact: [Phone].
```

**Output:**
- SMS sent to bystander
- `incidents/{id}` updated with `accepted_at` timestamp
- `doctors/{id}` updated with `current_incident: incident_id`

---

### 3. **on_incident_resolved** (Firestore Trigger)

**Trigger:** Document updated in `incidents/{incidentId}` (status field changed)

**Purpose:** Marks incident as complete and returns doctor to on-duty status.

**Activation Condition:**
- Only triggers when status changes to `"resolved"`

**Process Flow:**
1. Verifies status changed to "resolved"
2. Resets doctor availability:
   - Sets `is_on_duty = true`
   - Clears `current_incident` field
3. Records `resolved_at` timestamp on incident

**Output:**
- `doctors/{id}` reset to available state
- `incidents/{id}` updated with `resolved_at` timestamp

---

### 4. **approve_doctor** (HTTPS Endpoint)

**Type:** HTTP Cloud Function (POST)

**Endpoint:** `https://region-project.cloudfunctions.net/approve_doctor`

**Purpose:** Admin approval workflow for new doctors joining the network.

**Request:**
```json
{
  "doctorId": "doc123"
}
```

**Validation:**
- Method must be POST
- `doctorId` is required
- Doctor must exist in `doctors` collection

**Process Flow:**
1. Validates request and doctor existence
2. Updates doctor document:
   - Sets `is_approved = true`
   - Records `approved_at` timestamp
3. Sends welcome SMS via MSG91
4. Returns success response

**Welcome SMS Format:**
```
Welcome Dr. [Name]! Your First Responder Network account has been approved. 
You can now go on-duty and respond to emergencies.
```

**Response:**
```json
{
  "success": true,
  "message": "Dr. [Name] approved successfully"
}
```

**Error Responses:**
- `400` - Missing doctorId
- `404` - Doctor not found
- `405` - Method not allowed

---

### 5. **update_doctor_location** (HTTPS Endpoint)

**Type:** HTTP Cloud Function (POST)

**Endpoint:** `https://region-project.cloudfunctions.net/update_doctor_location`

**Purpose:** Real-time location tracking for doctors during emergencies.

**Request:**
```json
{
  "doctorId": "doc123",
  "lat": 12.9716,
  "lng": 77.5946
}
```

**Validation:**
- Method must be POST
- `doctorId` is required
- `lat` and `lng` must be valid numbers (not null)

**Process Flow:**
1. Validates all required fields
2. Creates/updates `doctor_locations/{doctorId}` document:
   - Stores latest lat/lng
   - Records `updated_at` timestamp
3. Returns success response

**Output:**
```json
{
  "success": true,
  "message": "Location updated"
}
```

**Error Responses:**
- `400` - Missing doctorId, lat, or lng
- `405` - Method not allowed

**Notes:**
- Called frequently by mobile app during active incidents
- Location data persists in separate collection for query efficiency
- Latest location used for new incident dispatch calculations

---

### 6. **submit_report** (HTTPS Endpoint)

**Type:** HTTP Cloud Function (POST)

**Endpoint:** `https://region-project.cloudfunctions.net/submit_report`

**Purpose:** Medical report submission after incident completion.

**Request:**
```json
{
  "incidentId": "incident123",
  "doctorId": "doc123",
  "vitals": {
    "pulse": 88,
    "bp": "120/80",
    "temperature": 98.6
  },
  "notes": "Patient stable, transferred to nearby hospital"
}
```

**Validation:**
- Method must be POST
- `incidentId` and `doctorId` are required
- `vitals` and `notes` are optional but recommended

**Process Flow:**
1. Validates required fields
2. Creates report document in `reports/{incidentId}`:
   - Stores vitals, notes, doctor info
   - Records `submitted_at` timestamp
3. Updates `incidents/{id}` to mark `report_submitted = true`
4. Returns success response

**Output:**
```json
{
  "success": true,
  "message": "Report submitted successfully"
}
```

**Error Responses:**
- `400` - Missing incidentId or doctorId
- `405` - Method not allowed

**Data Stored:**
- Medical vitals (pulse, BP, temperature, etc.)
- Doctor's clinical notes
- Submission timestamp for audit trail

---

## Firestore Database Schema

### Collections Overview

#### **incidents**
```
incidents/{incidentId}
├── lat (number)
├── lng (number)
├── emergency_type (string)
├── bystander_phone (string)
├── status (string): "pending" | "accepted" | "resolved"
├── assigned_doctor_id (string, optional)
├── accepted_at (timestamp, optional)
├── resolved_at (timestamp, optional)
└── report_submitted (boolean)
```

#### **doctors**
```
doctors/{doctorId}
├── name (string)
├── phone (string)
├── is_approved (boolean)
├── is_on_duty (boolean)
├── current_lat (number)
├── current_lng (number)
├── current_incident (string, optional)
├── fcm_token (string)
└── approved_at (timestamp, optional)
```

#### **doctor_locations**
```
doctor_locations/{doctorId}
├── doctorId (string)
├── lat (number)
├── lng (number)
└── updated_at (timestamp)
```

#### **dispatch_log**
```
dispatch_log/{incidentId}
├── incident_id (string)
├── doctors_alerted (array)
│  └── [
│       {
│         "doctorId": "string",
│         "fcm_token": "string",
│         "distance": number
│       }
│     ]
└── alerted_at (timestamp)
```

#### **reports**
```
reports/{incidentId}
├── incident_id (string)
├── doctor_id (string)
├── vitals (object, optional)
│  └── {
│       "pulse": number,
│       "bp": string,
│       "temperature": number
│     }
├── notes (string, optional)
└── submitted_at (timestamp)
```

---

## Environment Variables

Required environment variables (set in Firebase Cloud Functions):

```bash
MSG91_API_KEY          # API key from MSG91 SMS service
MSG91_SENDER_ID        # Sender ID registered with MSG91
```

**Optional:**
```bash
GOOGLE_APPLICATION_CREDENTIALS   # Path to Firebase service account key
```

**Set via Firebase Console:**
```bash
firebase functions:config:set msg91.apikey="YOUR_KEY" msg91.senderid="YOUR_ID"
firebase deploy --only functions
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| firebase-admin | ≥6.0.0 | Firebase Admin SDK |
| firebase-functions | ≥0.1.0 | Cloud Functions framework |
| requests | ≥2.31.0 | HTTP requests (MSG91 API) |
| google-auth | ≥2.0.0 | Google authentication |

---

## Deployment

### Deploy to Firebase

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:on_incident_created

# With verbose output
firebase deploy --only functions --debug
```

### View Logs

```bash
# Real-time logs
firebase functions:log

# Specific function logs
firebase functions:log --function=on_incident_created

# Export logs
firebase functions:log > logs.txt
```

### Monitoring

Access Firebase Console:
1. Go to `Cloud Functions` dashboard
2. Monitor execution time, errors, and memory usage
3. Set up alerts for function failures

---

## Development Guide

### Adding a New Function

1. **Create function file:**
   ```python
   # my_function.py
   from firebase_functions import firestore_fn, https_fn
   from firebase_admin import firestore
   
   @https_fn.on_request()
   def my_new_function(req: https_fn.Request):
       db = firestore.client()
       # Your logic here
       return https_fn.Response("Success", status=200)
   ```

2. **Export in main.py:**
   ```python
   from my_function import my_new_function
   __all__ = [...existing..., "my_new_function"]
   ```

3. **Test locally:**
   ```bash
   firebase emulators:start
   ```

4. **Deploy:**
   ```bash
   firebase deploy --only functions
   ```

### Common Patterns

#### Firestore Trigger (On Create/Update)
```python
@firestore_fn.on_document_created(document="collection/{docId}")
def on_create(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]):
    db = firestore.client()
    data = event.data.to_dict()
    doc_id = event.params["docId"]
    # Process...
```

#### Firestore Trigger (On Update with Before/After)
```python
@firestore_fn.on_document_updated(document="collection/{docId}")
def on_update(event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]]):
    before = event.data.before.to_dict()
    after = event.data.after.to_dict()
    # Compare and process...
```

#### HTTPS Function
```python
@https_fn.on_request()
def my_endpoint(req: https_fn.Request):
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)
    body = req.get_json()
    # Process...
    return https_fn.Response(json.dumps({...}), status=200, 
                            content_type="application/json")
```

### Testing

#### Unit Test Example
```python
# Test location update
def test_update_location():
    mock_db = MagicMock()
    # Mock Firestore calls
    # Call function
    # Assert database updates
```

#### Local Emulation
```bash
# Start emulator
firebase emulators:start --only firestore,functions

# In another terminal, run tests
pytest functions/
```

---

## Incident Workflow Diagram

```
1. Incident Created (Firestore)
   ↓
2. on_incident_created triggered
   ├─ Query nearby approved doctors
   ├─ Calculate distance (Haversine)
   ├─ Send FCM alerts to doctors within 50km
   └─ Log dispatch event
   ↓
3. Doctor Accepts (Firestore update)
   ↓
4. on_doctor_accepted triggered
   ├─ Send SMS to bystander
   ├─ Mark doctor as busy (current_incident)
   └─ Record accepted_at timestamp
   ↓
5. Doctor Submits Report (HTTPS POST)
   ├─ Store vitals & notes in reports collection
   └─ Mark incident report_submitted = true
   ↓
6. Incident Marked Resolved (Firestore update)
   ↓
7. on_incident_resolved triggered
   ├─ Reset doctor to on-duty status
   └─ Record resolved_at timestamp
```

---

## Performance Considerations

### Dispatch Efficiency
- **Distance Calculation:** O(n) where n = approved + on-duty doctors
- **Optimization:** Consider geohashing for large doctor populations
- **Radius:** Currently fixed at 50km - configurable if needed

### Real-time Location Updates
- **Collection:** Separate `doctor_locations` collection for fast queries
- **TTL:** Consider implementing automatic document expiration
- **Batch Updates:** Consolidate multiple location updates if needed

### Firestore Queries
- **Indexes:** Ensure composite indexes exist for:
  - `doctors.is_approved == true AND is_on_duty == true`
  - `doctor_locations.updated_at` (for cleanup jobs)

---

## Troubleshooting

### Function Not Triggering
- Check Firestore trigger path matches document structure
- Verify function is deployed: `firebase functions:list`
- Check function status in Firebase Console

### SMS Not Sending
- Verify MSG91 credentials in environment variables
- Check SMS balance in MSG91 account
- Review MSG91 API response in function logs

### High Latency
- Check Firestore read/write operations
- Monitor function memory and CPU usage
- Consider splitting large operations into smaller tasks

### FCM Push Notifications Not Delivered
- Verify doctor FCM tokens are valid
- Check FCM token refresh in mobile app
- Ensure proper Firebase project configuration

---

## Security Best Practices

1. **Firestore Security Rules:**
   - Only approve operations are allowed through HTTPS endpoints
   - Trigger functions execute with elevated privileges

2. **Input Validation:**
   - All endpoints validate required fields
   - Sanitize data before database operations

3. **SMS/FCM Credentials:**
   - Never commit API keys to version control
   - Use Firebase environment variables
   - Rotate credentials regularly

4. **Rate Limiting:**
   - Implement rate limiting for HTTPS endpoints if needed
   - Monitor unusual dispatch patterns

---

## Future Enhancement Ideas

- [ ] Real-time incident updates via WebSockets
- [ ] Doctor performance analytics dashboard
- [ ] Automated dispatch optimization (ML-based)
- [ ] Multi-language SMS support
- [ ] Integration with hospital management systems
- [ ] Automated incident follow-up emails
- [ ] Doctor availability scheduling
- [ ] Cost optimization for FCM/SMS bulk messaging

---

## Support & Maintenance

- **Firebase Console:** [Firebase Console](https://console.firebase.google.com)
- **Cloud Functions Docs:** [Firebase Cloud Functions Guide](https://firebase.google.com/docs/functions)
- **MSG91 API Docs:** [MSG91 Documentation](https://docs.msg91.com)

---

**Last Updated:** April 2026  
**Maintainers:** First Responder Network Team
