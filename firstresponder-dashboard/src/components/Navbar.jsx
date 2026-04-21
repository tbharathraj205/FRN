import { Link } from "react-router-dom";

export default function Navbar() {
    return (
        <nav className="bg-white border-b border-gray-300 px-6 py-4 flex items-center justify-between">

            {/* Logo */}
            <div className="flex items-center gap-2">
                <span className="text-2xl">🚨</span>
                <span className="text-gray-900 font-bold text-lg">First Responder Network</span>
                <span className="text-gray-600 text-xs ml-2">Control Room</span>
            </div>

            {/* Nav Links */}
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
            </div>
        </nav>
    );
}