import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { useEffect, useState } from "react";
import { auth } from "./firebase/config";
import Dashboard from "./pages/Dashboard";
import CreateIncident from "./pages/CreateIncident";
import IncidentDetail from "./pages/IncidentDetail";
import DoctorsManagement from "./pages/DoctorsManagement";
import IncidentHistory from "./pages/IncidentHistory";
import Login from "./pages/Login";

function ProtectedRoute({ children }) {
  const [isAuthenticated, setIsAuthenticated] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged((user) => {
      setIsAuthenticated(!!user);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  if (loading) {
    return <div className="min-h-screen bg-white flex items-center justify-center"><p className="text-gray-600">Loading...</p></div>;
  }

  return isAuthenticated ? children : <Navigate to="/login" replace />;
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
        <Route path="/create-incident" element={<ProtectedRoute><CreateIncident /></ProtectedRoute>} />
        <Route path="/incident/:id" element={<ProtectedRoute><IncidentDetail /></ProtectedRoute>} />
        <Route path="/doctors" element={<ProtectedRoute><DoctorsManagement /></ProtectedRoute>} />
        <Route path="/history" element={<ProtectedRoute><IncidentHistory /></ProtectedRoute>} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;