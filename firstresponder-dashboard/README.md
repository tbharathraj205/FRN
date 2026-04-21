# First Responder Network - Dashboard Frontend

## Overview

The First Responder Network Dashboard is a React-based web application that serves as the central control room for emergency dispatch coordinators. It provides real-time incident management, doctor oversight, location tracking, and comprehensive incident history tracking.

**Technology Stack:**
- **Frontend Framework:** React 19.2.4
- **Build Tool:** Vite 8.0.1
- **Routing:** React Router DOM 7.14.0
- **Styling:** Tailwind CSS 4.2.2
- **Backend Database:** Firebase Firestore
- **Authentication:** Firebase Auth
- **HTTP Client:** Axios 1.14.0
- **Maps:** React Leaflet 5.0.0 + Leaflet 1.9.4
- **Runtime:** Node.js with ES Modules

---

## Project Structure

```
firstresponder-dashboard/
├── src/
│   ├── main.jsx                    # Entry point
│   ├── App.jsx                     # Router setup
│   ├── App.css                     # App styles
│   ├── index.css                   # Global styles
│   │
│   ├── pages/                      # Page components
│   │   ├── Dashboard.jsx           # Main control room (real-time incidents)
│   │   ├── CreateIncident.jsx      # Manual incident creation form
│   │   ├── IncidentDetail.jsx      # Incident status & timeline
│   │   ├── DoctorsManagement.jsx   # Doctor approval & management
│   │   ├── IncidentHistory.jsx     # All incidents log
│   │   └── Login.jsx               # Authentication
│   │
│   ├── components/                 # Reusable components
│   │   ├── Navbar.jsx              # Top navigation
│   │   ├── DoctorCard.jsx          # Doctor info display + approve button
│   │   ├── IncidentCard.jsx        # Incident summary card
│   │   └── Map.jsx                 # Map placeholder
│   │
│   ├── services/                   # API & data services (empty - to implement)
│   │   ├── authService.js
│   │   ├── incidentService.js
│   │   └── doctorService.js
│   │
│   └── firebase/
│       └── config.js               # Firebase initialization
│
├── public/                          # Static assets
├── index.html                       # HTML entry point
├── vite.config.js                  # Vite configuration
├── eslint.config.js                # ESLint configuration
├── package.json                    # Dependencies
├── firebase.json                   # Firebase deployment config
└── README.md                       # This file
```

---

## Setup & Installation

### Prerequisites
- Node.js 18+ (with npm)
- Firebase project with Firestore & Auth enabled
- Firebase CLI (`npm install -g firebase-tools`)

### Local Development

1. **Install dependencies:**
   ```bash
   cd firstresponder-dashboard
   npm install
   ```

2. **Update Firebase config:**
   Edit `src/firebase/config.js` with your Firebase credentials:
   ```javascript
   const firebaseConfig = {
       apiKey: "YOUR_API_KEY",
       authDomain: "YOUR_PROJECT.firebaseapp.com",
       projectId: "YOUR_PROJECT_ID",
       storageBucket: "YOUR_PROJECT.firebasestorage.app",
       messagingSenderId: "YOUR_SENDER_ID",
       appId: "YOUR_APP_ID"
   };
   ```

3. **Start development server:**
   ```bash
   npm run dev
   ```
   Opens at `http://localhost:5173`

4. **Build for production:**
   ```bash
   npm run build
   ```

5. **Preview production build:**
   ```bash
   npm run preview
   ```

6. **Lint code:**
   ```bash
   npm run lint
   ```

### Deployment

**Deploy to Firebase Hosting:**
```bash
firebase login
firebase deploy
```

---

## Pages & Features

### 1. **Login Page** (`/login`)

**File:** `src/pages/Login.jsx`

**Purpose:** Authenticate dispatch operators and control room staff.

**Features:**
- Firebase email/password authentication
- Error handling for invalid credentials
- Redirect to dashboard on successful login
- Form validation

**Fields:**
- Email (e.g., operator@112.in)
- Password

**Key Code:**
```javascript
await signInWithEmailAndPassword(auth, email, password);
```

---

### 2. **Dashboard** (`/`)

**File:** `src/pages/Dashboard.jsx`

**Purpose:** Main control room showing real-time incident overview and dispatch status.

**Features:**
- **Real-time Stats:**
  - Active incidents (count & list)
  - On-duty doctors
  - Total incidents today
  - All-time incidents

- **Incident Management:**
  - List of active/pending incidents
  - Incident status badges (pending, accepted, on_scene, resolved)
  - Quick incident selection

- **Doctor Overview:**
  - On-duty doctor count
  - Available doctors for dispatch

- **Firestore Real-time Listeners:**
  ```javascript
  // Active incidents (status != resolved)
  const activeQ = query(collection(db, "incidents"), 
                        where("status", "!=", "resolved"));
  
  // On-duty doctors (is_on_duty == true AND is_approved == true)
  const doctorQ = query(collection(db, "doctors"), 
                        where("is_on_duty", "==", true),
                        where("is_approved", "==", true));
  ```

**UI Components:**
- Top status bar with metrics
- Incident cards list
- Responsive grid layout
- Logout button

---

### 3. **Create Incident** (`/create-incident`)

**File:** `src/pages/CreateIncident.jsx`

**Purpose:** Manual incident reporting form for dispatch operators.

**Features:**
- Emergency type selection (8 types)
- Location input (auto-detect or manual)
- Bystander phone number
- Form validation
- Loading state during dispatch

**Emergency Types:**
```
- Cardiac Arrest
- Road Accident
- Stroke
- Breathing Difficulty
- Severe Bleeding
- Unconscious Person
- Choking
- Other
```

**Location Input Methods:**
1. **Auto-detect:** Uses browser geolocation API
2. **Manual:** Enter latitude/longitude coordinates

**Database Operation:**
```javascript
await addDoc(collection(db, "incidents"), {
    emergency_type,
    lat, lng,
    address,
    bystander_phone,
    status: "pending",
    assigned_doctor_id: "",
    report_submitted: false,
    created_at: serverTimestamp(),
});
```

**Validation:**
- All fields required
- Phone number required
- Location must be set
- Valid numeric coordinates

**Error Handling:**
- Displays error messages
- Prevents submission on validation failure
- Shows loading state during dispatch

---

### 4. **Incident Detail** (`/incident/:id`)

**File:** `src/pages/IncidentDetail.jsx`

**Purpose:** Comprehensive view of individual incident with real-time status updates.

**Features:**
- **Incident Information:**
  - Emergency type
  - Location (lat/lng)
  - Bystander phone
  - Current status badge

- **Status Timeline:**
  - Visual progression: pending → accepted → on_scene → resolved
  - Checkmarks for completed steps
  - Color-coded steps (red for active)

- **Assigned Doctor:**
  - Doctor name and specialization
  - Doctor phone contact
  - Loading state while waiting for acceptance

**Real-time Updates:**
```javascript
// Listen to incident changes
const unsub = onSnapshot(doc(db, "incidents", id), (snap) => {
    const incident = snap.data();
    setIncident(incident);
    
    // Also load assigned doctor if exists
    if (incident.assigned_doctor_id) {
        // Load doctor details
    }
});
```

**Status Labels:**
- `pending`: Waiting for doctor
- `accepted`: Doctor on the way
- `on_scene`: Doctor on scene
- `resolved`: Resolved

---

### 5. **Doctors Management** (`/doctors`)

**File:** `src/pages/DoctorsManagement.jsx`

**Purpose:** Approve new doctors, manage doctor status, and track availability.

**Features:**
- **Doctor Statistics:**
  - Total doctors
  - Pending approval count
  - Approved doctors count
  - On-duty count

- **Filter Tabs:**
  - All doctors
  - Pending approval
  - Approved only
  - On-duty now

- **Real-time Listener:**
  ```javascript
  const unsub = onSnapshot(collection(db, "doctors"), (snap) => {
      setDoctors(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  });
  ```

- **Doctor Cards:**
  - Doctor name, specialization, phone
  - Approval status badge
  - On-duty/Off-duty indicator
  - Approve button (for pending doctors)

**Backend Integration:**
- Calls `approve_doctor` Cloud Function via API endpoint
- Updates doctor document in Firestore
- Triggers welcome SMS via MSG91

---

### 6. **Incident History** (`/history`)

**File:** `src/pages/IncidentHistory.jsx`

**Purpose:** View complete log of all incidents with filtering and details.

**Features:**
- **Incident Table:**
  - Emergency type
  - Bystander phone
  - Status badge (color-coded)
  - Report submission status
  - View Details button

- **Sorting:**
  - Incidents sorted by `created_at` (descending)
  - Latest incidents first

- **Detail Modal:**
  - Emergency type
  - Location coordinates
  - Bystander phone
  - Current status
  - Assigned doctor ID
  - Report submitted status

**Real-time Listener:**
```javascript
const q = query(collection(db, "incidents"), 
                orderBy("created_at", "desc"));
const unsub = onSnapshot(q, (snap) => {
    setIncidents(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
});
```

**Status Colors:**
- Yellow: pending
- Blue: accepted
- Purple: on_scene
- Green: resolved

---

## Components

### Navbar

**File:** `src/components/Navbar.jsx`

**Purpose:** Navigation header appearing on all pages (except login).

**Props:** None

**Features:**
- Logo and app title
- Navigation links:
  - Dashboard (`/`)
  - Doctors (`/doctors`)
  - History (`/history`)
- Styled with Tailwind CSS

**Usage:**
```jsx
import Navbar from "../components/Navbar";

export default function MyPage() {
    return (
        <div>
            <Navbar />
            {/* Page content */}
        </div>
    );
}
```

---

### DoctorCard

**File:** `src/components/DoctorCard.jsx`

**Purpose:** Display doctor information with approval functionality.

**Props:**
```javascript
{
    doctor: {
        id: string,
        name: string,
        specialization: string,
        phone: string,
        is_approved: boolean,
        is_on_duty: boolean
    }
}
```

**Features:**
- Doctor avatar (emoji)
- Name, specialization, phone
- On-duty/Off-duty badge
- Approve button (for pending doctors)
- Calls `approve_doctor` Cloud Function via Axios

**Backend API Call:**
```javascript
const APPROVE_URL = "https://approve-doctor-kl4browlmq-uc.a.run.app";

await axios.post(APPROVE_URL, { doctorId: doctor.id });
```

**Error Handling:** Shows alert on approval failure

---

### IncidentCard

**File:** `src/components/IncidentCard.jsx`

**Purpose:** Display incident summary in list format.

**Props:**
```javascript
{
    incident: {
        id: string,
        emergency_type: string,
        bystander_phone: string,
        lat: number,
        lng: number,
        status: string,
        assigned_doctor_id?: string
    }
}
```

**Features:**
- Emergency type with ambulance emoji
- Bystander phone
- Coordinates (lat/lng)
- Status badge (color-coded)
- "Doctor assigned" indicator
- Click to navigate to incident detail

**Click Handler:**
```javascript
navigate(`/incident/${incident.id}`)
```

---

## Routing

**File:** `src/App.jsx`

```
/login                 → Login page
/                      → Dashboard (home)
/create-incident       → Manual incident creation
/incident/:id          → Incident detail view
/doctors               → Doctors management & approval
/history               → Incident history log
```

**Protected Routes:** Currently not implemented - all pages are public after login

---

## Firebase Integration

**Configuration File:** `src/firebase/config.js`

**Exported Services:**
```javascript
export const db = getFirestore(app);      // Firestore database
export const auth = getAuth(app);         // Authentication
export const storage = getStorage(app);   // File storage
```

**Collections Used:**
1. **incidents** - Emergency reports
2. **doctors** - Doctor profiles and status
3. **dispatch_log** - Dispatch history
4. **reports** - Medical reports

**Real-time Features:**
- Firestore `onSnapshot()` listeners for live updates
- Real-time incident status synchronization
- Live doctor availability tracking

---

## API Integration

### Cloud Functions Endpoints

**Doctor Approval Endpoint:**
```javascript
const APPROVE_URL = "https://approve-doctor-kl4browlmq-uc.a.run.app";

// Called from DoctorCard.jsx
axios.post(APPROVE_URL, { 
    doctorId: "doctor123" 
})
```

**Request:**
```json
{
    "doctorId": "string"
}
```

**Response:**
```json
{
    "success": true,
    "message": "Dr. [Name] approved successfully"
}
```

**Error Handling:**
- 400: Missing doctorId
- 404: Doctor not found
- 405: Method not allowed

---

## Services Layer (To Implement)

Currently empty - these should be implemented for better code organization:

### authService.js
```javascript
// Should contain:
export const login = (email, password) => { ... }
export const logout = () => { ... }
export const getCurrentUser = () => { ... }
```

### incidentService.js
```javascript
// Should contain:
export const createIncident = (data) => { ... }
export const getIncident = (id) => { ... }
export const updateIncidentStatus = (id, status) => { ... }
export const getIncidentHistory = () => { ... }
```

### doctorService.js
```javascript
// Should contain:
export const getAllDoctors = () => { ... }
export const approveDoctor = (doctorId) => { ... }
export const updateDoctorStatus = (doctorId, status) => { ... }
```

---

## Key Features & Usage

### Real-time Incident Tracking
- Firestore listeners update UI automatically
- No manual refresh needed
- Live incident count updates

### Doctor Availability System
- Query for `is_approved == true AND is_on_duty == true`
- Real-time availability changes
- On-duty badge shows current status

### Incident Status Workflow
```
pending → accepted → on_scene → resolved
```

### Location Handling
1. **Manual Creation:**
   - Browser geolocation API or manual input
   - Coordinates displayed in dashboard

2. **Reverse Geocoding (Dashboard):**
   ```javascript
   fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`)
   ```
   - Converts coordinates to human-readable address
   - Falls back to coordinates if geocoding fails

3. **Map Integration:**
   - React Leaflet library integrated
   - Leaflet marker icons fixed for proper display
   - Map tiles from OpenStreetMap

### Form Validation
- All required fields validated before submission
- Phone number format validation
- Coordinate validation (must be numbers)
- Error messages displayed to user

### Loading & Error States
- Loading spinners during async operations
- Error message display
- Disabled buttons during submission
- Try-again functionality

---

## Development Guide

### Adding a New Page

1. **Create page component:**
   ```jsx
   // src/pages/NewPage.jsx
   import Navbar from "../components/Navbar";
   
   export default function NewPage() {
       return (
           <div>
               <Navbar />
               {/* Page content */}
           </div>
       );
   }
   ```

2. **Add route in App.jsx:**
   ```jsx
   <Route path="/new-page" element={<NewPage />} />
   ```

3. **Add navigation link in Navbar.jsx:**
   ```jsx
   <Link to="/new-page" className="...">
       New Page
   </Link>
   ```

### Adding a New Component

1. **Create component file:**
   ```jsx
   // src/components/MyComponent.jsx
   export default function MyComponent({ prop1, prop2 }) {
       return <div>{prop1}</div>;
   }
   ```

2. **Use in pages:**
   ```jsx
   import MyComponent from "../components/MyComponent";
   
   <MyComponent prop1="value" prop2="value" />
   ```

### Working with Firestore Data

**Read Data (One-time):**
```javascript
import { doc, getDoc } from "firebase/firestore";

const docSnap = await getDoc(doc(db, "collection", "docId"));
if (docSnap.exists()) {
    console.log(docSnap.data());
}
```

**Read Data (Real-time):**
```javascript
import { collection, onSnapshot, query, where } from "firebase/firestore";

const q = query(collection(db, "incidents"), 
                where("status", "!=", "resolved"));
const unsub = onSnapshot(q, (snapshot) => {
    const incidents = snapshot.docs.map(d => ({ 
        id: d.id, 
        ...d.data() 
    }));
});

// Don't forget to unsubscribe in cleanup
return () => unsub();
```

**Write Data:**
```javascript
import { addDoc, collection, serverTimestamp } from "firebase/firestore";

await addDoc(collection(db, "incidents"), {
    emergency_type: "Cardiac Arrest",
    lat: 12.9716,
    lng: 77.5946,
    status: "pending",
    created_at: serverTimestamp()
});
```

**Update Data:**
```javascript
import { doc, updateDoc } from "firebase/firestore";

await updateDoc(doc(db, "incidents", incidentId), {
    status: "accepted",
    assigned_doctor_id: doctorId
});
```

### Styling with Tailwind CSS

All components use Tailwind CSS utility classes:

```jsx
<div className="flex items-center gap-4 p-6 bg-white rounded-lg">
    <p className="text-gray-900 font-bold text-lg">Title</p>
</div>
```

**Common Utilities:**
- `p-4` - padding
- `m-2` - margin
- `bg-white` - background color
- `text-gray-900` - text color
- `rounded-lg` - border radius
- `flex gap-4` - flexbox with spacing
- `w-full` - full width
- `hover:bg-gray-100` - hover state

---

## State Management

Currently uses React hooks (useState, useEffect):
- `useState` for component state
- `useEffect` for side effects (Firestore listeners)
- Context API not implemented (could be added for global state)

**Future Improvement:** Consider Redux or Context API for complex state sharing

---

## Error Handling

**Try-Catch Blocks:**
```javascript
try {
    await addDoc(collection(db, "incidents"), data);
    navigate("/");
} catch (err) {
    setError("Failed to create incident. Try again.");
    console.error(err);
}
```

**Loading States:**
```javascript
const [loading, setLoading] = useState(false);

const handleSubmit = async () => {
    setLoading(true);
    try {
        // API call
    } finally {
        setLoading(false);
    }
};
```

**User Feedback:**
- Error messages in red text
- Success navigation after operations
- Loading spinners during async operations
- Disabled buttons during submission

---

## Performance Optimization

### Firestore Queries
- Use `where()` to filter at database level
- Order by indexed fields only
- Unsubscribe from listeners in cleanup

### React Optimization
- Functional components with hooks
- useEffect cleanup functions
- Avoid unnecessary re-renders

### Code Splitting
- React Router enables automatic code splitting
- Each page loads only when navigated

### Asset Optimization
- Vite bundle optimization
- Minified production builds
- CSS pruning with Tailwind CSS

---

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile browsers (iOS Safari, Chrome Mobile)

---

## Troubleshooting

### Firebase Connection Issues
- Verify Firebase credentials in `config.js`
- Check Firebase project is active
- Ensure Firestore database exists
- Check network connectivity

### Real-time Updates Not Working
- Verify Firestore security rules allow reads
- Check `onSnapshot` listeners are active
- Look for listener cleanup in useEffect
- Monitor browser console for errors

### Styling Issues
- Ensure Tailwind CSS is properly imported
- Check className syntax (Tailwind utilities)
- Clear browser cache and rebuild
- Verify `@tailwindcss/vite` plugin is loaded

### Map Display Issues
- Verify Leaflet CSS is imported
- Check marker icon paths are correct
- Ensure `react-leaflet` version compatibility
- Test in different browsers

### Authentication Fails
- Verify Firebase Auth is enabled
- Check user email/password format
- Ensure user exists in Firebase console
- Check Firebase security rules

---

## Deployment

### Firebase Hosting

```bash
# Build project
npm run build

# Deploy
firebase deploy
```

**Configuration:** `firebase.json`

### Environment Configuration

Create `.env` file for different environments:
```
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=...
```

Access in code:
```javascript
const apiKey = import.meta.env.VITE_FIREBASE_API_KEY;
```

### Pre-deployment Checklist
- [ ] Run linter: `npm run lint`
- [ ] Test all routes
- [ ] Test Firebase authentication
- [ ] Test real-time updates
- [ ] Test on mobile browsers
- [ ] Verify API endpoint URLs
- [ ] Check error handling
- [ ] Build production bundle: `npm run build`

---

## Future Enhancement Ideas

- [ ] **Protected Routes:** Add route guards for authenticated users
- [ ] **Role-based Access:** Different UI for operators vs. admins
- [ ] **Dark Mode:** Toggle between light/dark themes
- [ ] **Advanced Filtering:** Filter incidents by date, type, status
- [ ] **Doctor Search:** Search and filter doctors by specialization
- [ ] **Map Visualization:** Show all active incidents on interactive map
- [ ] **Push Notifications:** Browser notifications for new incidents
- [ ] **Export Reports:** Export incident history as CSV/PDF
- [ ] **Performance Analytics:** Dashboard with metrics and charts
- [ ] **Multi-language Support:** I18n translations
- [ ] **Offline Mode:** Service workers for offline functionality
- [ ] **Real-time Chat:** Communication between operators and doctors
- [ ] **Image Upload:** Attach photos to incident reports
- [ ] **Automated Tests:** Unit and integration tests
- [ ] **Improved Mobile UI:** Responsive mobile-first design
- [ ] **Doctor Performance Metrics:** Track doctor response times
- [ ] **Incident Clustering:** Group similar incidents
- [ ] **Automated Dispatch:** ML-based automatic doctor assignment

---

## Security Considerations

1. **Authentication:**
   - Firebase Auth handles password hashing
   - Email verification recommended
   - Session management automatic

2. **Firestore Security:**
   - Implement security rules for data access
   - Only allow authenticated users
   - Restrict operations by user role

3. **API Endpoints:**
   - Validate all inputs
   - Use HTTPS only
   - Implement rate limiting on Cloud Functions

4. **Sensitive Data:**
   - Never commit Firebase credentials
   - Use environment variables
   - Rotate API keys regularly

---

## Support & Resources

- **React Documentation:** [react.dev](https://react.dev)
- **Vite Guide:** [vitejs.dev](https://vitejs.dev)
- **Firebase Docs:** [firebase.google.com/docs](https://firebase.google.com/docs)
- **Tailwind CSS:** [tailwindcss.com](https://tailwindcss.com)
- **React Router:** [reactrouter.com](https://reactrouter.com)

---

**Last Updated:** April 2026  
**Maintainers:** First Responder Network Team
