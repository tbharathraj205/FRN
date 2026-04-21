import { useEffect, useState } from "react";
import { db } from "../firebase/config";
import { collection, onSnapshot, query, orderBy } from "firebase/firestore";
import Navbar from "../components/Navbar";

const statusColors = {
    pending: "bg-yellow-500",
    accepted: "bg-blue-500",
    on_scene: "bg-purple-500",
    resolved: "bg-green-500",
};

export default function IncidentHistory() {
    const [incidents, setIncidents] = useState([]);
    const [selected, setSelected] = useState(null);

    useEffect(() => {
        const q = query(collection(db, "incidents"), orderBy("created_at", "desc"));
        const unsub = onSnapshot(q, (snap) => {
            setIncidents(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
        });
        return () => unsub();
    }, []);

    return (
        <div className="min-h-screen bg-gray-100">
            <Navbar />

            <div className="p-6">
                <h1 className="text-gray-900 text-2xl font-bold mb-6">📋 Incident History</h1>

                {incidents.length === 0 ? (
                    <div className="text-gray-500 text-center mt-20">
                        <p className="text-4xl mb-3">📋</p>
                        <p>No incidents yet</p>
                    </div>
                ) : (
                    <div className="bg-white rounded-2xl overflow-hidden border border-gray-200">
                        <table className="w-full">
                            <thead>
                                <tr className="border-b border-gray-300">
                                    <th className="text-left text-gray-600 text-sm px-6 py-4">Emergency</th>
                                    <th className="text-left text-gray-600 text-sm px-6 py-4">Bystander</th>
                                    <th className="text-left text-gray-600 text-sm px-6 py-4">Status</th>
                                    <th className="text-left text-gray-600 text-sm px-6 py-4">Report</th>
                                    <th className="text-left text-gray-600 text-sm px-6 py-4">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {incidents.map((incident) => (
                                    <tr
                                        key={incident.id}
                                        className="border-b border-gray-200 hover:bg-gray-50 transition"
                                    >
                                        <td className="px-6 py-4">
                                            <p className="text-gray-900 font-medium">{incident.emergency_type}</p>
                                            <p className="text-gray-500 text-xs mt-1">
                                                {incident.lat?.toFixed(4)}, {incident.lng?.toFixed(4)}
                                            </p>
                                        </td>
                                        <td className="px-6 py-4 text-gray-700 text-sm">
                                            {incident.bystander_phone}
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={`px-3 py-1 rounded-full text-white text-xs font-semibold ${statusColors[incident.status] || "bg-gray-500"}`}>
                                                {incident.status}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4">
                                            {incident.report_submitted ? (
                                                <span className="text-green-600 text-sm">✓ Submitted</span>
                                            ) : (
                                                <span className="text-gray-500 text-sm">Pending</span>
                                            )}
                                        </td>
                                        <td className="px-6 py-4">
                                            <button
                                                onClick={() => setSelected(incident)}
                                                className="px-3 py-1 bg-gray-300 hover:bg-gray-400 text-gray-900 text-xs rounded-lg transition"
                                            >
                                                View Details
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}

                {/* Detail Modal */}
                {selected && (
                    <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
                        <div className="bg-white rounded-2xl p-6 w-full max-w-md border border-gray-300">
                            <h2 className="text-gray-900 font-bold text-xl mb-4">Incident Details</h2>
                            <div className="space-y-3">
                                <div>
                                    <p className="text-gray-600 text-xs">Emergency Type</p>
                                    <p className="text-gray-900">{selected.emergency_type}</p>
                                </div>
                                <div>
                                    <p className="text-gray-600 text-xs">Location</p>
                                    <p className="text-gray-900">{selected.lat}, {selected.lng}</p>
                                </div>
                                <div>
                                    <p className="text-gray-600 text-xs">Bystander Phone</p>
                                    <p className="text-gray-900">{selected.bystander_phone}</p>
                                </div>
                                <div>
                                    <p className="text-gray-600 text-xs">Status</p>
                                    <p className="text-gray-900">{selected.status}</p>
                                </div>
                                <div>
                                    <p className="text-gray-600 text-xs">Doctor Assigned</p>
                                    <p className="text-gray-900">{selected.assigned_doctor_id || "None"}</p>
                                </div>
                                <div>
                                    <p className="text-gray-600 text-xs">Report Submitted</p>
                                    <p className="text-gray-900">{selected.report_submitted ? "Yes" : "No"}</p>
                                </div>
                            </div>
                            <button
                                onClick={() => setSelected(null)}
                                className="mt-6 w-full py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition"
                            >
                                Close
                            </button>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}