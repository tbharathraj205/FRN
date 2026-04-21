import { useEffect, useState } from "react";
import { db } from "../firebase/config";
import { doc, onSnapshot } from "firebase/firestore";
import { useParams, useNavigate } from "react-router-dom";
import Navbar from "../components/Navbar";

const statusSteps = ["pending", "accepted", "on_scene", "resolved"];

const statusLabels = {
    pending: "Waiting for doctor",
    accepted: "Doctor on the way",
    on_scene: "Doctor on scene",
    resolved: "Resolved",
};

export default function IncidentDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [incident, setIncident] = useState(null);
    const [doctor, setDoctor] = useState(null);

    useEffect(() => {
        const unsub = onSnapshot(doc(db, "incidents", id), (snap) => {
            if (snap.exists()) {
                const data = { id: snap.id, ...snap.data() };
                setIncident(data);

                // Load assigned doctor if exists
                if (data.assigned_doctor_id) {
                    const doctorUnsub = onSnapshot(
                        doc(db, "doctors", data.assigned_doctor_id),
                        (dSnap) => {
                            if (dSnap.exists()) setDoctor({ id: dSnap.id, ...dSnap.data() });
                        }
                    );
                    return () => doctorUnsub();
                }
            }
        });
        return () => unsub();
    }, [id]);

    if (!incident) {
        return (
            <div className="min-h-screen bg-gray-100 flex items-center justify-center">
                <p className="text-gray-600">Loading incident...</p>
            </div>
        );
    }

    const currentStep = statusSteps.indexOf(incident.status);

    return (
        <div className="min-h-screen bg-gray-100">
            <Navbar />

            <div className="max-w-2xl mx-auto p-6">

                {/* Back Button */}
                <button
                    onClick={() => navigate("/")}
                    className="text-gray-600 hover:text-gray-900 text-sm mb-6 flex items-center gap-1"
                >
                    ← Back to Dashboard
                </button>

                {/* Incident Header */}
                <div className="bg-white rounded-2xl p-6 mb-4 border border-gray-200">
                    <div className="flex items-center justify-between mb-4">
                        <h1 className="text-gray-900 text-2xl font-bold">
                            🚨 {incident.emergency_type}
                        </h1>
                        <span className={`px-3 py-1 rounded-full text-white text-xs font-semibold ${incident.status === "resolved" ? "bg-green-500" :
                                incident.status === "accepted" ? "bg-blue-500" :
                                    incident.status === "on_scene" ? "bg-purple-500" : "bg-yellow-500"
                            }`}>
                            {statusLabels[incident.status]}
                        </span>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <p className="text-gray-600 text-xs">Location</p>
                            <p className="text-gray-900 text-sm">{incident.lat}, {incident.lng}</p>
                        </div>
                        <div>
                            <p className="text-gray-600 text-xs">Bystander Phone</p>
                            <p className="text-gray-900 text-sm">{incident.bystander_phone}</p>
                        </div>
                    </div>
                </div>

                {/* Status Timeline */}
                <div className="bg-white rounded-2xl p-6 mb-4 border border-gray-200">
                    <h2 className="text-gray-900 font-semibold mb-4">Status Timeline</h2>
                    <div className="flex items-center justify-between">
                        {statusSteps.map((step, index) => (
                            <div key={step} className="flex items-center">
                                <div className="flex flex-col items-center">
                                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${index <= currentStep
                                            ? "bg-red-600 text-white"
                                            : "bg-gray-300 text-gray-600"
                                        }`}>
                                        {index < currentStep ? "✓" : index + 1}
                                    </div>
                                    <p className="text-gray-600 text-xs mt-1 text-center w-20">
                                        {statusLabels[step]}
                                    </p>
                                </div>
                                {index < statusSteps.length - 1 && (
                                    <div className={`h-1 w-16 mx-1 rounded ${index < currentStep ? "bg-red-600" : "bg-gray-300"
                                        }`} />
                                )}
                            </div>
                        ))}
                    </div>
                </div>

                {/* Assigned Doctor */}
                <div className="bg-white rounded-2xl p-6 border border-gray-200">
                    <h2 className="text-gray-900 font-semibold mb-4">Assigned Doctor</h2>
                    {doctor ? (
                        <div className="flex items-center gap-4">
                            <div className="w-12 h-12 rounded-full bg-gray-200 flex items-center justify-center text-2xl">
                                👨‍⚕️
                            </div>
                            <div>
                                <p className="text-gray-900 font-semibold">{doctor.name}</p>
                                <p className="text-gray-600 text-sm">{doctor.specialization}</p>
                                <p className="text-gray-500 text-xs mt-1">📞 {doctor.phone}</p>
                            </div>
                        </div>
                    ) : (
                        <p className="text-gray-500">
                            Waiting for a doctor to accept...
                        </p>
                    )}
                </div>

            </div>
        </div>
    );
}