import { useEffect, useState } from "react";
import { db } from "../firebase/config";
import { collection, onSnapshot } from "firebase/firestore";
import Navbar from "../components/Navbar";
import DoctorCard from "../components/DoctorCard";

export default function DoctorsManagement() {
    const [doctors, setDoctors] = useState([]);
    const [filter, setFilter] = useState("all");

    useEffect(() => {
        const unsub = onSnapshot(collection(db, "doctors"), (snap) => {
            setDoctors(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
        });
        return () => unsub();
    }, []);

    const filtered = doctors.filter((d) => {
        if (filter === "pending") return !d.is_approved;
        if (filter === "approved") return d.is_approved;
        if (filter === "on_duty") return d.is_on_duty && d.is_approved;
        return true;
    });

    return (
        <div className="min-h-screen bg-gray-100">
            <Navbar />

            <div className="p-6">
                <h1 className="text-gray-900 text-2xl font-bold mb-6">👨‍⚕️ Doctors Management</h1>

                {/* Stats */}
                <div className="grid grid-cols-4 gap-4 mb-6">
                    <div className="bg-white rounded-xl p-4 border border-gray-200">
                        <p className="text-gray-600 text-sm">Total</p>
                        <p className="text-gray-900 text-2xl font-bold">{doctors.length}</p>
                    </div>
                    <div className="bg-white rounded-xl p-4 border border-gray-200">
                        <p className="text-gray-600 text-sm">Pending Approval</p>
                        <p className="text-yellow-600 text-2xl font-bold">
                            {doctors.filter((d) => !d.is_approved).length}
                        </p>
                    </div>
                    <div className="bg-white rounded-xl p-4 border border-gray-200">
                        <p className="text-gray-600 text-sm">Approved</p>
                        <p className="text-blue-600 text-2xl font-bold">
                            {doctors.filter((d) => d.is_approved).length}
                        </p>
                    </div>
                    <div className="bg-white rounded-xl p-4 border border-gray-200">
                        <p className="text-gray-600 text-sm">On Duty Now</p>
                        <p className="text-green-600 text-2xl font-bold">
                            {doctors.filter((d) => d.is_on_duty && d.is_approved).length}
                        </p>
                    </div>
                </div>

                {/* Filter Tabs */}
                <div className="flex gap-2 mb-4">
                    {["all", "pending", "approved", "on_duty"].map((f) => (
                        <button
                            key={f}
                            onClick={() => setFilter(f)}
                            className={`px-4 py-2 rounded-lg text-sm font-medium transition ${filter === f
                                ? "bg-red-600 text-white"
                                : "bg-white border border-gray-300 text-gray-600 hover:text-gray-900"
                                }`}
                        >
                            {f === "all" ? "All" : f === "pending" ? "Pending" : f === "approved" ? "Approved" : "On Duty"}
                        </button>
                    ))}
                </div>

                {/* Doctors List */}
                {filtered.length === 0 ? (
                    <div className="text-gray-500 text-center mt-20">
                        <p className="text-4xl mb-3">👨‍⚕️</p>
                        <p>No doctors found</p>
                    </div>
                ) : (
                    <div className="grid grid-cols-1 gap-4">
                        {filtered.map((doctor) => (
                            <DoctorCard key={doctor.id} doctor={doctor} />
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}