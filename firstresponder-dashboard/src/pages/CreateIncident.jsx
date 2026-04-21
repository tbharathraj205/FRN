import { useState } from "react";
import { db } from "../firebase/config";
import { collection, addDoc, serverTimestamp } from "firebase/firestore";
import { useNavigate } from "react-router-dom";
import Navbar from "../components/Navbar";

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

export default function CreateIncident() {
    const [emergencyType, setEmergencyType] = useState("");
    const [lat, setLat] = useState("");
    const [lng, setLng] = useState("");
    const [bystanderPhone, setBystanderPhone] = useState("");
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState("");
    const navigate = useNavigate();

    const handleGetLocation = () => {
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                setLat(pos.coords.latitude.toString());
                setLng(pos.coords.longitude.toString());
            },
            () => setError("Could not get location. Enter manually.")
        );
    };

    const handleDispatch = async () => {
        if (!emergencyType || !lat || !lng || !bystanderPhone) {
            setError("All fields are required");
            return;
        }
        setLoading(true);
        setError("");
        try {
            await addDoc(collection(db, "incidents"), {
                emergency_type: emergencyType,
                lat: parseFloat(lat),
                lng: parseFloat(lng),
                bystander_phone: bystanderPhone,
                status: "pending",
                assigned_doctor_id: "",
                report_submitted: false,
                created_at: serverTimestamp(),
            });
            navigate("/");
        } catch (err) {
            setError("Failed to create incident. Try again.");
        }
        setLoading(false);
    };

    return (
        <div className="min-h-screen bg-gray-900">
            <Navbar />

            <div className="max-w-xl mx-auto p-6">
                <h1 className="text-white text-2xl font-bold mb-6">🚨 Log New Emergency</h1>

                <div className="bg-gray-800 rounded-2xl p-6 space-y-5">

                    {/* Emergency Type */}
                    <div>
                        <label className="text-gray-400 text-sm">Emergency Type</label>
                        <select
                            value={emergencyType}
                            onChange={(e) => setEmergencyType(e.target.value)}
                            className="w-full mt-1 px-4 py-3 bg-gray-700 text-white rounded-lg outline-none focus:ring-2 focus:ring-red-500"
                        >
                            <option value="">Select emergency type</option>
                            {EMERGENCY_TYPES.map((type) => (
                                <option key={type} value={type}>{type}</option>
                            ))}
                        </select>
                    </div>

                    {/* Location */}
                    <div>
                        <label className="text-gray-400 text-sm">Location</label>
                        <button
                            onClick={handleGetLocation}
                            className="w-full mt-1 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition text-sm"
                        >
                            📍 Use Current Location
                        </button>
                        <div className="grid grid-cols-2 gap-3 mt-2">
                            <input
                                type="number"
                                value={lat}
                                onChange={(e) => setLat(e.target.value)}
                                placeholder="Latitude"
                                className="px-4 py-3 bg-gray-700 text-white rounded-lg outline-none focus:ring-2 focus:ring-red-500"
                            />
                            <input
                                type="number"
                                value={lng}
                                onChange={(e) => setLng(e.target.value)}
                                placeholder="Longitude"
                                className="px-4 py-3 bg-gray-700 text-white rounded-lg outline-none focus:ring-2 focus:ring-red-500"
                            />
                        </div>
                    </div>

                    {/* Bystander Phone */}
                    <div>
                        <label className="text-gray-400 text-sm">Bystander Phone Number</label>
                        <input
                            type="tel"
                            value={bystanderPhone}
                            onChange={(e) => setBystanderPhone(e.target.value)}
                            placeholder="10-digit mobile number"
                            className="w-full mt-1 px-4 py-3 bg-gray-700 text-white rounded-lg outline-none focus:ring-2 focus:ring-red-500"
                        />
                    </div>

                    {error && <p className="text-red-400 text-sm">{error}</p>}

                    {/* Dispatch Button */}
                    <button
                        onClick={handleDispatch}
                        disabled={loading}
                        className="w-full py-4 bg-red-600 hover:bg-red-700 text-white font-bold rounded-lg transition text-lg"
                    >
                        {loading ? "Dispatching..." : "🚀 Dispatch Alert"}
                    </button>
                </div>
            </div>
        </div>
    );
}