import { useEffect, useState } from "react";
import { db } from "../firebase/config";
import { collection, onSnapshot, query, orderBy, where, getDocs, limit } from "firebase/firestore";
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
    const [expandedId, setExpandedId] = useState(null);
    const [reportCache, setReportCache] = useState({});
    const [loadingReport, setLoadingReport] = useState(null);

    useEffect(() => {
        const q = query(collection(db, "incidents"), orderBy("created_at", "desc"));
        const unsub = onSnapshot(q, (snap) => {
            setIncidents(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
        });
        return () => unsub();
    }, []);

    const fetchReport = async (incidentId) => {
        if (reportCache[incidentId] !== undefined) return;
        setLoadingReport(incidentId);
        try {
            const q = query(
                collection(db, "reports"),
                where("incident_id", "==", incidentId),
                limit(1)
            );
            const snap = await getDocs(q);
            if (!snap.empty) {
                setReportCache((prev) => ({ ...prev, [incidentId]: snap.docs[0].data() }));
            } else {
                setReportCache((prev) => ({ ...prev, [incidentId]: null }));
            }
        } catch (e) {
            console.error("Error fetching report:", e);
            setReportCache((prev) => ({ ...prev, [incidentId]: null }));
        }
        setLoadingReport(null);
    };

    const toggleExpand = (incidentId) => {
        if (expandedId === incidentId) {
            setExpandedId(null);
        } else {
            setExpandedId(incidentId);
            fetchReport(incidentId);
        }
    };

    const formatTimestamp = (ts) => {
        if (!ts) return "Unknown";
        const dt = ts.toDate ? ts.toDate() : new Date(ts);
        return dt.toLocaleString("en-IN", {
            day: "numeric",
            month: "short",
            year: "numeric",
            hour: "numeric",
            minute: "2-digit",
            hour12: true,
        });
    };

    const outcomeColor = (outcome) => {
        if (!outcome) return "text-gray-500 bg-gray-100 border-gray-200";
        const lower = outcome.toLowerCase();
        if (lower.includes("success") || lower.includes("stabilized"))
            return "text-green-700 bg-green-50 border-green-200";
        if (lower.includes("critical") || lower.includes("ambulance"))
            return "text-amber-700 bg-amber-50 border-amber-200";
        if (lower.includes("fatal") || lower.includes("deceased"))
            return "text-red-700 bg-red-50 border-red-200";
        return "text-gray-700 bg-gray-50 border-gray-200";
    };

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
                                    <>
                                        <tr
                                            key={incident.id}
                                            className="border-b border-gray-200 hover:bg-gray-50 transition cursor-pointer"
                                            onClick={() => toggleExpand(incident.id)}
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
                                                <div className="flex items-center gap-2">
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); setSelected(incident); }}
                                                        className="px-3 py-1 bg-gray-300 hover:bg-gray-400 text-gray-900 text-xs rounded-lg transition"
                                                    >
                                                        View Details
                                                    </button>
                                                    <span className="text-gray-400 text-xs">
                                                        {expandedId === incident.id ? "▲ Hide Report" : "▼ View Report"}
                                                    </span>
                                                </div>
                                            </td>
                                        </tr>

                                        {/* EXPANDABLE REPORT ROW */}
                                        {expandedId === incident.id && (
                                            <tr key={`${incident.id}-report`} className="bg-gray-50">
                                                <td colSpan="5" className="px-6 py-5">
                                                    {renderReport(incident.id, reportCache, loadingReport, outcomeColor, formatTimestamp)}
                                                </td>
                                            </tr>
                                        )}
                                    </>
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

function renderReport(incidentId, reportCache, loadingReport, outcomeColor, formatTimestamp) {
    if (loadingReport === incidentId) {
        return (
            <div className="flex items-center gap-2 text-gray-500 text-sm py-2">
                <svg className="animate-spin h-4 w-4 text-red-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                Loading report...
            </div>
        );
    }

    const report = reportCache[incidentId];

    if (report === null || report === undefined) {
        return (
            <div className="flex items-center gap-2 text-red-500 text-sm bg-red-50 px-4 py-3 rounded-xl border border-red-200">
                <span>ℹ️</span>
                No report submitted for this incident.
            </div>
        );
    }

    const outcome = report.outcome || "N/A";
    const notes = report.notes || "No notes";
    const actionsTaken = report.actions_taken || [];
    const vitals = report.vitals || [];
    const submittedAt = report.submitted_at;

    return (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Outcome */}
            <div className="space-y-1">
                <p className="text-gray-400 text-xs font-bold tracking-wider uppercase">🏁 Outcome</p>
                <span className={`inline-block px-3 py-1.5 rounded-lg text-sm font-semibold border ${outcomeColor(outcome)}`}>
                    {outcome}
                </span>
            </div>

            {/* Submitted At */}
            <div className="space-y-1">
                <p className="text-gray-400 text-xs font-bold tracking-wider uppercase">🕐 Submitted At</p>
                <p className="text-gray-700 text-sm font-medium">{formatTimestamp(submittedAt)}</p>
            </div>

            {/* Actions Taken */}
            {actionsTaken.length > 0 && (
                <div className="space-y-1">
                    <p className="text-gray-400 text-xs font-bold tracking-wider uppercase">✅ Actions Taken</p>
                    <div className="flex flex-wrap gap-1.5">
                        {actionsTaken.map((action, i) => (
                            <span
                                key={i}
                                className="px-2.5 py-1 bg-blue-50 text-blue-700 text-xs font-semibold rounded-lg border border-blue-200"
                            >
                                {action}
                            </span>
                        ))}
                    </div>
                </div>
            )}

            {/* Vitals */}
            {vitals.length > 0 && (
                <div className="space-y-1">
                    <p className="text-gray-400 text-xs font-bold tracking-wider uppercase">💊 Vitals</p>
                    <div className="flex flex-wrap gap-1.5">
                        {vitals.map((vital, i) => (
                            <span
                                key={i}
                                className="px-2.5 py-1 bg-green-50 text-green-700 text-xs font-semibold rounded-lg border border-green-200"
                            >
                                {vital}
                            </span>
                        ))}
                    </div>
                </div>
            )}

            {/* Notes */}
            <div className="md:col-span-2 space-y-1">
                <p className="text-gray-400 text-xs font-bold tracking-wider uppercase">📝 Notes</p>
                <div className="bg-white px-4 py-3 rounded-xl border border-gray-200 text-gray-700 text-sm leading-relaxed">
                    {notes}
                </div>
            </div>
        </div>
    );
}