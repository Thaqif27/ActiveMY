import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from './firebase';
import { doc, getDoc } from 'firebase/firestore';

import Login from './Login';
import DashboardLayout from './DashboardLayout';
import EventsManager from './EventsManager';
import NewlyScrapedEvents from './NewlyScrapedEvents';
import UsersManager from './UsersManager';
import ScrapeLogs from './ScrapeLogs';
import MapScreen from './MapScreen';

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        const userDoc = await getDoc(doc(db, 'users', firebaseUser.uid));
        if (userDoc.exists() && userDoc.data().role === 'admin') {
          setUser(firebaseUser);
        } else {
          setUser(null);
        }
      } else {
        setUser(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  if (loading) {
    return <div className="min-h-screen flex items-center justify-center bg-slate-50">Loading...</div>;
  }

  return (
    <Router>
      <Routes>
        <Route 
          path="/login" 
          element={!user ? <Login onLogin={setUser} /> : <Navigate to="/" />} 
        />
        <Route 
          path="/*" 
          element={user ? <DashboardLayout user={user} /> : <Navigate to="/login" />} 
        />
      </Routes>
    </Router>
  );
}

export default App;
