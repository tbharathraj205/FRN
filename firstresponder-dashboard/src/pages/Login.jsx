import { useState } from "react";
import { auth } from "../firebase/config";
import { signInWithEmailAndPassword } from "firebase/auth";
import { useNavigate } from "react-router-dom";

export default function Login() {
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [error, setError] = useState("");
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const handleLogin = async () => {
        setLoading(true);
        setError("");
        try {
            await signInWithEmailAndPassword(auth, email, password);
            navigate("/");
        } catch (err) {
            setError("Invalid email or password");
        }
        setLoading(false);
    };

    const handleKeyPress = (e) => {
        if (e.key === "Enter") {
            handleLogin();
        }
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-red-50 to-white flex items-center justify-center p-4">
            <div className="bg-white p-8 rounded-2xl shadow-2xl w-full max-w-md border-t-4 border-red-600">

                {/* Logo */}
                <div className="text-center mb-8">
                    <div className="text-5xl mb-3">🚨</div>
                    <h1 className="text-3xl font-bold text-red-600">First Responder Network</h1>
                    <p className="text-gray-600 text-sm mt-2">Control Room Login</p>
                </div>

                {/* Form */}
                <div className="space-y-5">
                    <div>
                        <label className="text-gray-700 text-sm font-semibold block mb-2">Email Address</label>
                        <input
                            type="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            onKeyPress={handleKeyPress}
                            placeholder="operator@112.in"
                            className="w-full px-4 py-3 border-2 border-gray-200 text-gray-900 rounded-lg outline-none focus:border-red-600 focus:ring-2 focus:ring-red-200 transition"
                        />
                    </div>

                    <div>
                        <label className="text-gray-700 text-sm font-semibold block mb-2">Password</label>
                        <input
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            onKeyPress={handleKeyPress}
                            placeholder="••••••••"
                            className="w-full px-4 py-3 border-2 border-gray-200 text-gray-900 rounded-lg outline-none focus:border-red-600 focus:ring-2 focus:ring-red-200 transition"
                        />
                    </div>

                    {error && <p className="text-red-600 text-sm font-medium bg-red-50 p-3 rounded-lg">{error}</p>}

                    <button
                        onClick={handleLogin}
                        disabled={loading}
                        className="w-full py-3 bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white font-semibold rounded-lg transition duration-200 transform hover:scale-105"
                    >
                        {loading ? "Logging in..." : "Login"}
                    </button>
                </div>
            </div>
        </div>
    );
}