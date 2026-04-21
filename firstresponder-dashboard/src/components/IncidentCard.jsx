import { useNavigate } from "react-router-dom";

const statusColors = {
    pending: "bg-yellow-500",
    accepted: "bg-blue-500",
    on_scene: "bg-purple-500",
    resolved: "bg-green-500",
};

const statusLabels = {
    pending: "Waiting for doctor",
    accepted: "Doctor on the way",
    on_scene: "Doctor on scene",
    resolved: "Resolved",
};

export default function IncidentCard({ incident }) {
    const navigate = useNavigate();

    return (
        <div
            onClick={() => navigate(`/incident/${incident.id}`)}
            className="bg-gray-800 rounded-xl p-5 cursor-pointer hover:bg-gray-700 transition border border-gray-700"
        >
            <div className="flex items-center justify-between">

                {/* Left — Incident Info */}
                <div className="flex items-center gap-4">
                    <div className="text-3xl">🚑</div>
                    <div>
                        <h3 className="text-white font-semibold text-lg">
                            {incident.emergency_type || "Unknown Emergency"}
                        </h3>
                        <p className="text-gray-400 text-sm mt-1">
                            Bystander: {incident.bystander_phone || "N/A"}
                        </p>
                        <p className="text-gray-500 text-xs mt-1">
                            Lat: {incident.lat}, Lng: {incident.lng}
                        </p>
                    </div>
                </div>

                {/* Right — Status Badge */}
                <div className="text-right">
                    <span className={`px-3 py-1 rounded-full text-white text-xs font-semibold ${statusColors[incident.status] || "bg-gray-500"}`}>
                        {statusLabels[incident.status] || incident.status}
                    </span>
                    {incident.assigned_doctor_id && (
                        <p className="text-gray-400 text-xs mt-2">
                            Doctor assigned ✓
                        </p>
                    )}
                </div>
            </div>
        </div>
    );
}