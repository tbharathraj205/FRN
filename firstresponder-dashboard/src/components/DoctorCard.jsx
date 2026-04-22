import axios from "axios";
import { useState } from "react";
import { db } from "../firebase/config";
import { doc, deleteDoc } from "firebase/firestore";

const APPROVE_URL = "https://approve-doctor-kl4browlmq-uc.a.run.app";

export default function DoctorCard({ doctor, onReject }) {
    const [loading, setLoading] = useState(false);
    const [approved, setApproved] = useState(doctor.is_approved);
    const [rejecting, setRejecting] = useState(false);

    const handleApprove = async () => {
        setLoading(true);
        try {
            await axios.post(APPROVE_URL, { doctorId: doctor.id });
            setApproved(true);
        } catch (err) {
            alert("Failed to approve doctor. Try again.");
        }
        setLoading(false);
    };

    const handleReject = async () => {
        if (!window.confirm(`Are you sure you want to reject and delete all details for ${doctor.name}? This cannot be undone.`)) {
            return;
        }

        setRejecting(true);
        try {
            await deleteDoc(doc(db, "doctors", doctor.id));
            if (onReject) onReject(doctor.id);
        } catch (err) {
            alert("Failed to reject doctor. Try again.");
        }
        setRejecting(false);
    };

    return (
        <div className="bg-white rounded-xl p-5 border border-gray-300">
            <div className="flex items-center justify-between">

                {/* Left — Doctor Info */}
                <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-full bg-gray-200 flex items-center justify-center text-2xl">
                        👨‍⚕️
                    </div>
                    <div>
                        <h3 className="text-gray-900 font-semibold text-lg">{doctor.name}</h3>
                        <p className="text-gray-600 text-sm">{doctor.specialization}</p>
                        <p className="text-gray-500 text-xs mt-1">📞 {doctor.phone}</p>
                    </div>
                </div>

                {/* Right — Status + Action */}
                <div className="flex items-center gap-3">

                    {/* On Duty Badge */}
                    {approved && (
                        <span className={`px-3 py-1 rounded-full text-xs font-semibold ${doctor.is_on_duty
                                ? "bg-green-600 text-white"
                                : "bg-gray-300 text-gray-600"
                            }`}>
                            {doctor.is_on_duty ? "On Duty" : "Off Duty"}
                        </span>
                    )}

                    {/* Approve/Reject Buttons */}
                    {!approved ? (
                        <div className="flex gap-2">
                            <button
                                onClick={handleApprove}
                                disabled={loading}
                                className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded-lg transition disabled:opacity-50"
                            >
                                {loading ? "Approving..." : "✓ Approve"}
                            </button>
                            <button
                                onClick={handleReject}
                                disabled={rejecting}
                                className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-sm rounded-lg transition disabled:opacity-50"
                            >
                                {rejecting ? "Rejecting..." : "✕ Reject"}
                            </button>
                        </div>
                    ) : (
                        <span className="px-3 py-1 bg-green-600 text-white text-xs rounded-full font-semibold">
                            ✓ Approved
                        </span>
                    )}
                </div>
            </div>
        </div>
    );
}