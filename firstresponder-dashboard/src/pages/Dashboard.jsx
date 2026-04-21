import { useEffect, useState } from "react";
import { db } from "../firebase/config";
import { collection, onSnapshot, query, where, addDoc, serverTimestamp, doc, updateDoc } from "firebase/firestore";
import { MapContainer, TileLayer, Marker, useMapEvents } from "react-leaflet";
import { useNavigate } from "react-router-dom";
import { auth } from "../firebase/config";
import { signOut } from "firebase/auth";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

// Fix leaflet marker icons
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
    iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
    shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

const EMERGENCY_TYPES = [
    "Cardiac Arrest",
    "Road Accident",
    "Stroke",
    "Breathing Difficulty",
    "Severe Bleeding",
    "Unconscious Person",
    "Choking",
    "Other",
];

function MapClickHandler({ onMapClick }) {
    useMapEvents({
        click(e) {
            onMapClick(e.latlng.lat, e.latlng.lng);
        },
    });
    return null;
}

export default function Dashboard() {
    const [incidents, setIncidents] = useState([]);
    const [onlineDoctors, setOnlineDoctors] = useState(0);
    const [totalIncidents, setTotalIncidents] = useState(0);
    const [todayIncidents, setTodayIncidents] = useState(0);
    const [activeTab, setActiveTab] = useState("dispatch");
    const [resourceFilter, setResourceFilter] = useState("all");
    const [incidentFilter, setIncidentFilter] = useState("active");
    const [emergencyType, setEmergencyType] = useState("Cardiac Arrest");
    const [priority, setPriority] = useState("Medium");
    const [lat, setLat] = useState(13.0835);
    const [lng, setLng] = useState(80.272);
    const [address, setAddress] = useState("");
    const [doctors, setDoctors] = useState(1);
    const [ambulances, setAmbulances] = useState(1);
    const [locationSet, setLocationSet] = useState(false);
    const [bystanderPhone, setBystanderPhone] = useState("");
    const [eta, setEta] = useState("12");
    const [markerPos, setMarkerPos] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState("");
    const [onDutyDoctors, setOnDutyDoctors] = useState([]);
    const navigate = useNavigate();

    useEffect(() => {
        // All active incidents (including resolved)
        const activeQ = query(collection(db, "incidents"));
        const unsub1 = onSnapshot(activeQ, (snap) => {
            setIncidents(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
        });

        // On duty doctors
        const doctorQ = query(
            collection(db, "doctors"),
            where("is_on_duty", "==", true),
            where("is_approved", "==", true)
        );
        const unsub2 = onSnapshot(doctorQ, (snap) => {
            setOnlineDoctors(snap.size);
            setOnDutyDoctors(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
        });

        // All incidents
        const unsub3 = onSnapshot(collection(db, "incidents"), (snap) => {
            setTotalIncidents(snap.size);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            const todayCount = snap.docs.filter((d) => {
                const ts = d.data().created_at?.toDate?.();
                return ts && ts >= today;
            }).length;
            setTodayIncidents(todayCount);
        });

        return () => { unsub1(); unsub2(); unsub3(); };
    }, []);

    const handleMapClick = async (lat, lng) => {
        const latFormatted = parseFloat(lat.toFixed(4));
        const lngFormatted = parseFloat(lng.toFixed(4));
        setLat(latFormatted);
        setLng(lngFormatted);
        setMarkerPos([lat, lng]);
        
        // Reverse geocoding - fetch address from coordinates
        try {
            const response = await fetch(
                `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`
            );
            const data = await response.json();
            const fetchedAddress = data.address?.road || data.address?.street || data.display_name || `${latFormatted}, ${lngFormatted}`;
            setAddress(fetchedAddress);
        } catch (err) {
            console.error("Geocoding error:", err);
            setAddress(`${latFormatted}, ${lngFormatted}`);
        }
        
        setLocationSet(true);
    };

    const handleCoordinateChange = (newLat, newLng) => {
        setLat(newLat);
        setLng(newLng);
        if (newLat && newLng) {
            setMarkerPos([newLat, newLng]);
            setLocationSet(true);
        }
    };

    const handleDispatch = async () => {
        if (!bystanderPhone) { setError("Caller phone is required"); return; }
        if (!locationSet) { setError("Location must be set on map"); return; }
        setLoading(true);
        setError("");
        try {
            await addDoc(collection(db, "incidents"), {
                emergency_type: emergencyType,
                priority: priority,
                lat,
                lng,
                address: address,
                bystander_phone: bystanderPhone,
                status: "pending",
                assigned_doctor_id: "",
                report_submitted: false,
                created_at: serverTimestamp(),
            });
            setBystanderPhone("");
            setMarkerPos(null);
            setAddress("");
            setLocationSet(false);
            setPriority("Medium");
            setDoctors(1);
            setAmbulances(1);
            setActiveTab("incidents");
        } catch (err) {
            setError("Failed to dispatch. Try again.");
        }
        setLoading(false);
    };

    const handleLogout = async () => {
        try {
            await signOut(auth);
            // ProtectedRoute will automatically handle the redirect after auth state changes
        } catch (err) {
            console.error("Logout error:", err);
            alert("Error signing out: " + err.message);
        }
    };

    const getTimeAgo = (timestamp) => {
        if (!timestamp) return "just now";
        const date = timestamp.toDate?.() || new Date(timestamp);
        const now = new Date();
        const seconds = Math.floor((now - date) / 1000);
        
        if (seconds < 60) return `${seconds}s ago`;
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
        if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m ago`;
        return `${Math.floor(seconds / 86400)}d ago`;
    };

    const markAsResolved = async (incidentId) => {
        try {
            const incidentRef = doc(db, "incidents", incidentId);
            await updateDoc(incidentRef, {
                status: "resolved"
            });
        } catch (err) {
            console.error("Error marking as resolved:", err);
            alert("Failed to mark as resolved");
        }
    };

    const statusColors = {
        pending: "#f59e0b",
        accepted: "#3b82f6",
        on_scene: "#8b5cf6",
        resolved: "#10b981",
    };

    return (
        <div style={{ height: "100vh", display: "flex", flexDirection: "column", background: "#f5f5f5", color: "#333", fontFamily: "monospace" }}>

            {/* Top Bar */}
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "10px 20px", borderBottom: "1px solid #e0e0e0", background: "#c53030" }}>

                {/* Logo */}
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <span style={{ fontSize: 22 }}></span>
                    <span style={{ fontWeight: "bold", letterSpacing: 2, fontSize: 14, color: "white" }}>FRN CONTROL ROOM</span>
                    <span style={{ background: "rgba(255,255,255,0.3)", color: "white", fontSize: 10, padding: "2px 8px", borderRadius: 4, letterSpacing: 1 }}>● LIVE</span>
                </div>

                {/* Stats */}
                <div style={{ display: "flex", gap: 4 }}>
                    {[
                        { label: "ACTIVE", value: incidents.filter(i => i.status !== "resolved").length, bg: "#ffe0e0", text: "#c53030" },
                        { label: "ON DUTY", value: onlineDoctors, bg: "#c8e6c9", text: "#2e7d32" },
                        { label: "TOTAL TODAY", value: todayIncidents, bg: "#ffe0b2", text: "#e65100" },
                        { label: "ALL TIME", value: totalIncidents, bg: "#bbdefb", text: "#0d47a1" },
                    ].map((stat) => (
                        <div key={stat.label} style={{ background: stat.bg, padding: "6px 16px", borderRadius: 6, textAlign: "center", minWidth: 80, color: stat.text }}>
                            <div style={{ fontSize: 20, fontWeight: "bold" }}>{stat.value}</div>
                            <div style={{ fontSize: 9, opacity: 0.9, letterSpacing: 1 }}>{stat.label}</div>
                        </div>
                    ))}
                </div>

                {/* User */}
                <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                    <span style={{ color: "white", fontSize: 12 }}>{auth.currentUser?.email}</span>
                    <button onClick={handleLogout} style={{ background: "rgba(255,255,255,0.2)", border: "1px solid rgba(255,255,255,0.4)", color: "white", padding: "6px 14px", borderRadius: 6, cursor: "pointer", fontSize: 12 }}>
                        LOGOUT
                    </button>
                </div>
            </div>

            {/* Main Content */}
            <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>

                {/* Map */}
                <div style={{ flex: 1, position: "relative" }}>
                    <MapContainer
                        center={[13.0835, 80.272]}
                        zoom={13}
                        style={{ height: "100%", width: "100%" }}
                    >
                        <TileLayer
                            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                            attribution="© OpenStreetMap"
                        />
                        <MapClickHandler onMapClick={handleMapClick} />
                        {markerPos && <Marker position={markerPos} />}
                    </MapContainer>
                    {!markerPos && (
                        <div style={{ position: "absolute", bottom: 20, left: "50%", transform: "translateX(-50%)", background: "rgba(0,0,0,0.7)", color: "white", padding: "8px 16px", borderRadius: 20, fontSize: 12, pointerEvents: "none", zIndex: 1000 }}>
                            Click map to set incident location
                        </div>
                    )}
                </div>

                {/* Right Panel */}
                <div style={{ width: 360, background: "white", borderLeft: "1px solid #e0e0e0", display: "flex", flexDirection: "column", overflowY: "auto" }}>

                    {/* Tabs */}
                    <div style={{ display: "flex", borderBottom: "1px solid #e0e0e0", position: "sticky", top: 0, background: "white", zIndex: 10 }}>
                        {["dispatch", "incidents", "resources"].map((tab) => (
                            <button
                                key={tab}
                                onClick={() => setActiveTab(tab)}
                                style={{
                                    flex: 1, padding: "12px 0", background: "transparent", border: "none",
                                    borderBottom: activeTab === tab ? "2px solid #c53030" : "2px solid transparent",
                                    color: activeTab === tab ? "#c53030" : "#999",
                                    cursor: "pointer", fontSize: 11, letterSpacing: 1, textTransform: "uppercase", fontWeight: activeTab === tab ? "600" : "400"
                                }}
                            >
                                {tab === "dispatch" ? " Dispatch" : tab === "incidents" ? `📋 Incidents (${incidents.filter(i => i.status !== "resolved").length})` : "👥 RESPONDERS"}
                            </button>
                        ))}
                    </div>

                    {/* Tab Content */}
                    <div style={{ flex: 1, padding: 16, overflowY: "auto" }}>

                        {/* Dispatch Tab */}
                        {activeTab === "dispatch" && (
                            <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
                                <h3 style={{ color: "#c53030", letterSpacing: 2, fontSize: 12, margin: 0, fontWeight: "bold" }}> CREATE REQUEST</h3>

                                {/* Location Set Indicator */}
                                {locationSet && (
                                    <div style={{ background: "#c8e6c9", borderRadius: 8, padding: "10px 14px", fontSize: 12, color: "#2e7d32", display: "flex", alignItems: "center", gap: 8, border: "1px solid #a5d6a7" }}>
                                        <span>✓</span>
                                        <div>
                                            <div style={{ fontWeight: "bold", marginBottom: 2 }}>Location set</div>
                                            <div style={{ fontSize: 11, opacity: 0.9 }}>{lat.toFixed(4)}, {lng.toFixed(4)}</div>
                                        </div>
                                    </div>
                                )}

                                {!locationSet && (
                                    <div style={{ background: "#f0f0f0", borderRadius: 8, padding: "10px 14px", fontSize: 12, color: "#666" }}>
                                        👆 Click on the map to set incident location
                                    </div>
                                )}

                                {/* Request Type */}
                                <div>
                                    <label style={{ fontSize: 11, color: "#666", letterSpacing: 1, fontWeight: "600" }}>REQUEST TYPE</label>
                                    <select value={emergencyType} onChange={(e) => setEmergencyType(e.target.value)}
                                        style={{ width: "100%", marginTop: 6, padding: "10px 12px", background: "white", border: "1px solid #ddd", color: "#333", borderRadius: 6, fontSize: 13 }}>
                                        {EMERGENCY_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
                                    </select>
                                </div>

                                {/* Address / Landmark */}
                                <div>
                                    <label style={{ fontSize: 11, color: "#666", letterSpacing: 1, fontWeight: "600" }}>ADDRESS / LANDMARK</label>
                                    <textarea value={address} onChange={(e) => setAddress(e.target.value)}
                                        placeholder="Auto-filled from map - or type manually"
                                        rows={2}
                                        style={{ width: "100%", marginTop: 6, padding: "10px 12px", background: "white", border: "1px solid #ddd", color: "#333", borderRadius: 6, fontSize: 12, resize: "none", boxSizing: "border-box", fontFamily: "monospace" }}
                                    />
                                </div>

                                {/* Latitude & Longitude */}
                                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                                    <div>
                                        <label style={{ fontSize: 11, color: "#666", letterSpacing: 1, fontWeight: "600" }}>LATITUDE</label>
                                        <input type="number" value={lat} onChange={(e) => handleCoordinateChange(parseFloat(e.target.value) || 0, lng)} step="0.0001"
                                            style={{ width: "100%", marginTop: 6, padding: "10px 12px", background: "white", border: "1px solid #ddd", color: "#333", borderRadius: 6, fontSize: 12, boxSizing: "border-box", fontFamily: "monospace" }} />
                                    </div>
                                    <div>
                                        <label style={{ fontSize: 11, color: "#666", letterSpacing: 1, fontWeight: "600" }}>LONGITUDE</label>
                                        <input type="number" value={lng} onChange={(e) => handleCoordinateChange(lat, parseFloat(e.target.value) || 0)} step="0.0001"
                                            style={{ width: "100%", marginTop: 6, padding: "10px 12px", background: "white", border: "1px solid #ddd", color: "#333", borderRadius: 6, fontSize: 12, boxSizing: "border-box", fontFamily: "monospace" }} />
                                    </div>
                                </div>

                                {/* Caller Phone */}
                                <div>
                                    <label style={{ fontSize: 11, color: "#666", letterSpacing: 1, fontWeight: "600" }}>CALLER PHONE</label>
                                    <input type="tel" value={bystanderPhone} onChange={(e) => setBystanderPhone(e.target.value)}
                                        placeholder="+91 99999 99999"
                                        style={{ width: "100%", marginTop: 6, padding: "10px 12px", background: "white", border: "1px solid #ddd", color: "#333", borderRadius: 6, fontSize: 12, boxSizing: "border-box", fontFamily: "monospace" }} />
                                </div>

                                {error && <p style={{ color: "#c53030", fontSize: 12, margin: 0, padding: "8px 12px", background: "#ffebee", borderRadius: 6 }}>{error}</p>}

                                <button onClick={handleDispatch} disabled={loading}
                                    style={{ width: "100%", padding: "12px", background: "#c53030", border: "none", color: "white", borderRadius: 8, cursor: loading ? "not-allowed" : "pointer", fontWeight: "bold", fontSize: 13, letterSpacing: 1, opacity: loading ? 0.7 : 1 }}>
                                     {loading ? "DISPATCHING..." : "DISPATCH EMERGENCY"}
                                </button>
                            </div>
                        )}

                        {/* Incidents Tab */}
                        {activeTab === "incidents" && (
                            <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
                                <h3 style={{ color: "#c53030", letterSpacing: 2, fontSize: 12, margin: "0 0 12px 0", fontWeight: "bold" }}>📋 INCIDENTS</h3>
                                
                                {/* Filter Buttons */}
                                <div style={{ display: "flex", gap: 8 }}>
                                    <button
                                        onClick={() => setIncidentFilter("active")}
                                        style={{
                                            padding: "8px 14px",
                                            borderRadius: 6,
                                            border: incidentFilter === "active" ? "2px solid #c53030" : "2px solid #ddd",
                                            background: incidentFilter === "active" ? "#ffebee" : "#fff",
                                            color: incidentFilter === "active" ? "#c53030" : "#666",
                                            cursor: "pointer",
                                            fontSize: 12,
                                            fontWeight: "600",
                                        }}
                                    >
                                        Active only
                                    </button>
                                    <button
                                        onClick={() => setIncidentFilter("all")}
                                        style={{
                                            padding: "8px 14px",
                                            borderRadius: 6,
                                            border: incidentFilter === "all" ? "2px solid #c53030" : "2px solid #ddd",
                                            background: incidentFilter === "all" ? "#ffebee" : "#fff",
                                            color: incidentFilter === "all" ? "#c53030" : "#666",
                                            cursor: "pointer",
                                            fontSize: 12,
                                            fontWeight: "600",
                                        }}
                                    >
                                        All incidents
                                    </button>
                                </div>

                                <span style={{ fontSize: 11, color: "#999" }}>{incidents.filter(i => incidentFilter === "active" ? i.status !== "resolved" : true).length} shown</span>

                                {/* Incident Cards */}
                                {incidents.filter(i => incidentFilter === "active" ? i.status !== "resolved" : true).length === 0 ? (
                                    <p style={{ color: "#999", fontSize: 13, textAlign: "center", marginTop: 20 }}>No incidents found</p>
                                ) : incidents.filter(i => incidentFilter === "active" ? i.status !== "resolved" : true).map((inc) => (
                                    <div key={inc.id}
                                        style={{
                                            background: "white",
                                            borderRadius: 12,
                                            padding: 14,
                                            border: "2px solid #e0e0e0",
                                            cursor: "pointer",
                                            transition: "all 0.2s",
                                        }}
                                        onMouseOver={(e) => e.currentTarget.style.borderColor = "#c53030"}
                                        onMouseOut={(e) => e.currentTarget.style.borderColor = "#e0e0e0"}
                                    >
                                        {/* Header */}
                                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "start", marginBottom: 10 }}>
                                            <div style={{ flex: 1 }}>
                                                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                                                    <span style={{ fontSize: 18, color: "#c53030" }}>●</span>
                                                    <span style={{ fontWeight: "bold", fontSize: 14, color: "#333" }}>{inc.emergency_type}</span>
                                                </div>
                                                <span style={{ fontSize: 11, color: "#999", display: "block", marginTop: 4 }}>{getTimeAgo(inc.created_at)} · {inc.address || `${inc.lat?.toFixed(4)}, ${inc.lng?.toFixed(4)}`}</span>
                                            </div>
                                            <span style={{ background: inc.status === "pending" ? "#fef2f2" : "#f0f9ff", color: inc.status === "pending" ? "#c53030" : "#3b82f6", fontSize: 11, padding: "4px 10px", borderRadius: 12, fontWeight: "600", border: `1px solid ${inc.status === "pending" ? "#feca5d" : "#bfdbfe"}` }}>
                                                {inc.status === "pending" ? "pending" : inc.status === "accepted" || inc.status === "on_scene" ? "active" : "resolved"}
                                            </span>
                                        </div>

                                        {/* Location */}
                                        <div style={{ background: "#f9f9f9", borderRadius: 8, padding: 10, marginBottom: 10, fontSize: 11, color: "#666", borderLeft: "3px solid #c53030" }}>
                                            📍 {inc.address || `${inc.lat?.toFixed(4)}, ${inc.lng?.toFixed(4)}`}
                                        </div>

                                        {/* Ambulance ETA */}
                                        <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 10, fontSize: 11, color: "#666" }}>
                                            🚑 <span style={{ fontWeight: "600" }}>Amb. ETA: 12 min</span>
                                        </div>

                                        {/* Responders */}
                                        {inc.assigned_doctor_id && (
                                            <div style={{ background: "#f9f9f9", borderRadius: 8, padding: 10, marginBottom: 10 }}>
                                                <div style={{ fontSize: 10, color: "#999", fontWeight: "bold", marginBottom: 6, letterSpacing: 0.5 }}>RESPONDERS (1)</div>
                                                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                                                    <span style={{ fontSize: 12, fontWeight: "600", color: "#333" }}>Dr. {onDutyDoctors.find(d => d.id === inc.assigned_doctor_id)?.name || "Unknown"}</span>
                                                    <span style={{ fontSize: 10, color: "#999", fontWeight: "600" }}>Notified</span>
                                                </div>
                                            </div>
                                        )}

                                        {/* Mark as Resolved Button */}
                                        {inc.status !== "resolved" && (
                                            <button
                                                onClick={() => markAsResolved(inc.id)}
                                                style={{
                                                    width: "100%",
                                                    padding: "10px",
                                                    borderRadius: 8,
                                                    border: "2px solid #e0e0e0",
                                                    background: "white",
                                                    color: "#666",
                                                    fontWeight: "600",
                                                    fontSize: 12,
                                                    cursor: "pointer",
                                                    transition: "all 0.2s"
                                                }}
                                                onMouseOver={(e) => {
                                                    e.currentTarget.style.borderColor = "#c53030";
                                                    e.currentTarget.style.color = "#c53030";
                                                }}
                                                onMouseOut={(e) => {
                                                    e.currentTarget.style.borderColor = "#e0e0e0";
                                                    e.currentTarget.style.color = "#666";
                                                }}
                                            >
                                                ✓ Mark as Resolved
                                            </button>
                                        )}
                                    </div>
                                ))}
                            </div>
                        )}

                        {/* Responders Tab */}
                        {activeTab === "responders" && (
                            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                                <h3 style={{ color: "#c53030", letterSpacing: 2, fontSize: 12, margin: 0, fontWeight: "bold" }}>👨‍⚕️ RESPONDERS ({onlineDoctors} ON DUTY)</h3>
                                {onDutyDoctors.length === 0 ? (
                                    <p style={{ color: "#999", fontSize: 13, textAlign: "center", marginTop: 40 }}>No doctors on duty</p>
                                ) : onDutyDoctors.map((doc) => (
                                    <div key={doc.id} style={{ background: "white", borderRadius: 8, padding: 12, border: "1px solid #e0e0e0" }}>
                                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "start" }}>
                                            <div>
                                                <div style={{ fontWeight: "bold", fontSize: 12, color: "#333" }}>{doc.name || "Unknown"}</div>
                                                <div style={{ fontSize: 11, color: "#666", marginTop: 2 }}>{doc.specialization || "Specialist"}</div>
                                            </div>
                                            <span style={{ background: "#4caf50", color: "white", fontSize: 9, padding: "3px 8px", borderRadius: 10, fontWeight: "600" }}>● Available</span>
                                        </div>
                                        <div style={{ fontSize: 11, color: "#666", marginTop: 6 }}>📞 {doc.phone || "N/A"}</div>
                                    </div>
                                ))}
                                <button onClick={() => navigate("/doctors")}
                                    style={{ width: "100%", padding: 12, background: "white", border: "1px solid #e0e0e0", color: "#666", borderRadius: 6, cursor: "pointer", fontSize: 12, marginTop: 8 }}>
                                    View All Doctors →
                                </button>
                            </div>
                        )}

                        {/* Resources Tab */}
                        {activeTab === "resources" && (
                            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                                {/* Resource Count Section */}
                                <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: 10 }}>
                                    <div style={{ background: "#f5f5f5", borderRadius: 6, padding: 12, textAlign: "center" }}>
                                        <div style={{ fontSize: 12, color: "#666", fontWeight: "bold", marginBottom: 4 }}>{onDutyDoctors.length}</div>
                                        <div style={{ fontSize: 9, color: "#999", letterSpacing: 0.5 }}>DOCTORS</div>
                                    </div>
                                </div>



                                {/* Doctor Cards */}
                                <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                                    {onDutyDoctors.length > 0 ? (
                                        onDutyDoctors.map((doc) => (
                                            <div key={doc.id} style={{ background: "white", borderRadius: 8, padding: 14, border: "1px solid #e0e0e0" }}>
                                                <div style={{ display: "flex", gap: 12, marginBottom: 12 }}>
                                                    <div style={{ width: 40, height: 40, borderRadius: "50%", background: "#f5f5f5", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: "bold", color: "#c53030", fontSize: 16 }}>
                                                        {doc.name ? doc.name.charAt(0).toUpperCase() : "R"}
                                                    </div>
                                                    <div style={{ flex: 1 }}>
                                                        <div style={{ fontWeight: "bold", fontSize: 12, color: "#333" }}>{doc.name || "Doctor Name"}</div>
                                                        <div style={{ fontSize: 10, color: "#999", marginTop: 2 }}>{doc.specialization || "Cardiologist - MH/12345"}</div>
                                                        <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 4 }}>
                                                            <span style={{ background: "#e0e0e0", color: "#666", fontSize: 8, padding: "2px 6px", borderRadius: 3, fontWeight: "600" }}>👨‍⚕️ Doctor</span>
                                                            <span style={{ background: "#4caf50", color: "white", fontSize: 8, padding: "2px 6px", borderRadius: 3, fontWeight: "600" }}>● Available</span>
                                                        </div>
                                                    </div>
                                                </div>
                                                <div style={{ fontSize: 10, color: "#999", marginBottom: 12 }}>📞 {doc.phone || "9876543210"}</div>
                                            </div>
                                        ))
                                    ) : (
                                        <div style={{ textAlign: "center", padding: "20px", color: "#999" }}>
                                            <p style={{ fontSize: 12 }}>No active doctors available</p>
                                        </div>
                                    )}
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}