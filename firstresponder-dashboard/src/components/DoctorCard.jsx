import axios from "axios";
import { useState } from "react";

const APPROVE_URL = "https://approve-doctor-kl4browlmq-uc.a.run.app";

export default function DoctorCard({ doctor }) {
    const [loading, setLoading] = useState(false);
    const [approved, setApproved] = useState(doctor.is_approved);

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

                    {/* Approve Button */}
                    {!approved ? (
                        <button
                            onClick={handleApprove}
                            disabled={loading}
                            className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded-lg transition"
                        >
                            {loading ? "Approving..." : "✓ Approve"}
                        </button>
                    ) : (
                        <span className="px-3 py-1 bg-red-600 text-white text-xs rounded-full font-semibold">
                            ✓ Approved
                        </span>
                    )}
                </div>
            </div>
        </div>
    );
}