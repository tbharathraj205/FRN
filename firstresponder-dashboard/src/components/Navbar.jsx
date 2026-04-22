import { Link } from "react-router-dom";
import { useEffect, useState } from "react";
import { db } from "../firebase/config";
import { collection, onSnapshot, query, where, doc, updateDoc, deleteDoc } from "firebase/firestore";

export default function Navbar() {
    const [pendingDoctors, setPendingDoctors] = useState([]);
    const [showModal, setShowModal] = useState(false);
    const [actionLoading, setActionLoading] = useState({});

    useEffect(() => {
        const pendingQ = query(
            collection(db, "doctors"),
            where("is_approved", "==", false)
        );
        const unsub = onSnapshot(
            pendingQ,
            (snap) => {
                const docs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
                console.log("Pending doctors found:", docs.length, docs);
                setPendingDoctors(docs);
            },
            (error) => {
                console.error("Error fetching pending doctors:", error);
            }
        );
        return () => unsub();
    }, []);

    const handleApprove = async (doctorId, doctorName) => {
        setActionLoading({ ...actionLoading, [doctorId]: "approving" });
        try {
            await updateDoc(doc(db, "doctors", doctorId), {
                is_approved: true,
                approved_at: new Date(),
            });
            alert(`${doctorName} approved!`);
        } catch (err) {
            alert("Error approving doctor");
            console.error(err);
        }
        setActionLoading({ ...actionLoading, [doctorId]: null });
    };

    const handleReject = async (doctorId, doctorName) => {
        if (!window.confirm(`Delete all details for ${doctorName}? This cannot be undone.`)) return;
        
        setActionLoading({ ...actionLoading, [doctorId]: "rejecting" });
        try {
            await deleteDoc(doc(db, "doctors", doctorId));
            alert(`${doctorName} rejected`);
        } catch (err) {
            alert("Error rejecting doctor");
            console.error(err);
        }
        setActionLoading({ ...actionLoading, [doctorId]: null });
    };

    return (
        <>
            <nav className="bg-white border-b border-gray-300 px-6 py-4 flex items-center justify-between">

                {/* Logo */}
                <div className="flex items-center gap-2">
                    <span className="text-2xl">🚨</span>
                    <span className="text-gray-900 font-bold text-lg">First Responder Network</span>
                    <span className="text-gray-600 text-xs ml-2">Control Room</span>
                </div>

                {/* Nav Links + Approve Button */}
                <div className="flex items-center gap-6">
                    <Link to="/" className="text-gray-600 hover:text-gray-900 text-sm transition">
                        Dashboard
                    </Link>
                    <Link to="/doctors" className="text-gray-600 hover:text-gray-900 text-sm transition">
                        Doctors
                    </Link>
                    <Link to="/history" className="text-gray-600 hover:text-gray-900 text-sm transition">
                        History
                    </Link>

                    {/* Approve Doctors Button */}
                    <button
                        onClick={() => setShowModal(true)}
                        style={{
                            padding: "8px 16px",
                            backgroundColor: pendingDoctors.length > 0 ? "#fbbf24" : "#d1d5db",
                            color: "white",
                            border: "none",
                            borderRadius: "6px",
                            fontWeight: "600",
                            fontSize: "14px",
                            cursor: "pointer",
                            display: "flex",
                            alignItems: "center",
                            gap: "8px",
                            transition: "all 0.2s",
                        }}
                        onMouseEnter={(e) => {
                            if (pendingDoctors.length > 0) {
                                e.currentTarget.style.backgroundColor = "#d97706";
                            }
                        }}
                        onMouseLeave={(e) => {
                            if (pendingDoctors.length > 0) {
                                e.currentTarget.style.backgroundColor = "#fbbf24";
                            }
                        }}
                    >
                        👨‍⚕️ Approve ({pendingDoctors.length})
                    </button>
                </div>
            </nav>

            {/* Modal */}
            {showModal && (
                <div style={{
                    position: "fixed",
                    inset: 0,
                    backgroundColor: "rgba(0, 0, 0, 0.5)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    zIndex: 50,
                    padding: "16px"
                }}>
                    <div style={{
                        backgroundColor: "white",
                        borderRadius: "12px",
                        boxShadow: "0 20px 25px -5px rgba(0, 0, 0, 0.1)",
                        maxWidth: "640px",
                        width: "100%",
                        maxHeight: "80vh",
                        overflowY: "auto"
                    }}>

                        {/* Header */}
                        <div style={{
                            position: "sticky",
                            top: 0,
                            backgroundColor: "white",
                            borderBottom: "1px solid #d1d5db",
                            padding: "24px",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "space-between"
                        }}>
                            <h2 style={{
                                fontSize: "24px",
                                fontWeight: "bold",
                                color: "#111827",
                                margin: 0
                            }}>
                                Approve Doctors ({pendingDoctors.length})
                            </h2>
                            <button
                                onClick={() => setShowModal(false)}
                                style={{
                                    fontSize: "24px",
                                    color: "#6b7280",
                                    border: "none",
                                    background: "none",
                                    cursor: "pointer",
                                    padding: 0
                                }}
                            >
                                ✕
                            </button>
                        </div>

                        {/* Content */}
                        <div style={{ padding: "24px" }}>
                            {pendingDoctors.length === 0 ? (
                                <div style={{ textAlign: "center", paddingTop: "48px", paddingBottom: "48px" }}>
                                    <p style={{ fontSize: "32px", marginBottom: "8px" }}>✓</p>
                                    <p style={{ color: "#4b5563", fontSize: "18px", fontWeight: "600" }}>
                                        All doctors approved!
                                    </p>
                                </div>
                            ) : (
                                <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                                    {pendingDoctors.map((doctor) => (
                                        <div
                                            key={doctor.id}
                                            style={{
                                                backgroundColor: "#f9fafb",
                                                border: "2px solid #fbbf24",
                                                borderRadius: "8px",
                                                padding: "16px"
                                            }}
                                        >
                                            {/* Doctor Info */}
                                            <div style={{
                                                display: "flex",
                                                alignItems: "flex-start",
                                                gap: "16px",
                                                marginBottom: "16px"
                                            }}>
                                                <div style={{
                                                    width: "48px",
                                                    height: "48px",
                                                    borderRadius: "50%",
                                                    backgroundColor: "#fbbf24",
                                                    display: "flex",
                                                    alignItems: "center",
                                                    justifyContent: "center",
                                                    fontSize: "20px",
                                                    fontWeight: "bold",
                                                    color: "#333"
                                                }}>
                                                    {doctor.name ? doctor.name.charAt(0).toUpperCase() : "D"}
                                                </div>
                                                <div style={{ flex: 1 }}>
                                                    <h3 style={{
                                                        fontSize: "18px",
                                                        fontWeight: "bold",
                                                        color: "#111827",
                                                        margin: "0 0 4px 0"
                                                    }}>
                                                        {doctor.name || "Unknown"}
                                                    </h3>
                                                    <p style={{
                                                        color: "#6b7280",
                                                        fontSize: "14px",
                                                        margin: "0 0 8px 0"
                                                    }}>
                                                        {doctor.specialization || "Specialist"}
                                                    </p>
                                                    <p style={{ color: "#9ca3af", fontSize: "12px", margin: "4px 0" }}>
                                                        License: {doctor.license_number || "N/A"}
                                                    </p>
                                                    <p style={{ color: "#9ca3af", fontSize: "12px", margin: "4px 0" }}>
                                                        Email: {doctor.email || "N/A"}
                                                    </p>
                                                    <p style={{ color: "#9ca3af", fontSize: "12px", margin: "4px 0" }}>
                                                        Phone: {doctor.phone || "N/A"}
                                                    </p>
                                                </div>
                                            </div>

                                            {/* Action Buttons */}
                                            <div style={{ display: "flex", gap: "12px" }}>
                                                <button
                                                    onClick={() => handleApprove(doctor.id, doctor.name)}
                                                    disabled={actionLoading[doctor.id]}
                                                    style={{
                                                        flex: 1,
                                                        padding: "8px 16px",
                                                        backgroundColor: "#16a34a",
                                                        color: "white",
                                                        fontWeight: "600",
                                                        borderRadius: "8px",
                                                        border: "none",
                                                        cursor: actionLoading[doctor.id] ? "not-allowed" : "pointer",
                                                        opacity: actionLoading[doctor.id] ? 0.5 : 1,
                                                        transition: "all 0.2s"
                                                    }}
                                                    onMouseEnter={(e) => {
                                                        if (!actionLoading[doctor.id]) {
                                                            e.currentTarget.style.backgroundColor = "#15803d";
                                                        }
                                                    }}
                                                    onMouseLeave={(e) => {
                                                        if (!actionLoading[doctor.id]) {
                                                            e.currentTarget.style.backgroundColor = "#16a34a";
                                                        }
                                                    }}
                                                >
                                                    {actionLoading[doctor.id] === "approving" ? "Approving..." : "✓ Approve"}
                                                </button>
                                                <button
                                                    onClick={() => handleReject(doctor.id, doctor.name)}
                                                    disabled={actionLoading[doctor.id]}
                                                    style={{
                                                        flex: 1,
                                                        padding: "8px 16px",
                                                        backgroundColor: "#dc2626",
                                                        color: "white",
                                                        fontWeight: "600",
                                                        borderRadius: "8px",
                                                        border: "none",
                                                        cursor: actionLoading[doctor.id] ? "not-allowed" : "pointer",
                                                        opacity: actionLoading[doctor.id] ? 0.5 : 1,
                                                        transition: "all 0.2s"
                                                    }}
                                                    onMouseEnter={(e) => {
                                                        if (!actionLoading[doctor.id]) {
                                                            e.currentTarget.style.backgroundColor = "#b91c1c";
                                                        }
                                                    }}
                                                    onMouseLeave={(e) => {
                                                        if (!actionLoading[doctor.id]) {
                                                            e.currentTarget.style.backgroundColor = "#dc2626";
                                                        }
                                                    }}
                                                >
                                                    {actionLoading[doctor.id] === "rejecting" ? "Rejecting..." : "✕ Reject"}
                                                </button>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </>
    );
}