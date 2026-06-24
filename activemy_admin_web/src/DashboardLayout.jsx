import React from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import { auth } from './firebase';
import { signOut } from 'firebase/auth';
import { LayoutDashboard, Users, Calendar, LogOut, Terminal, Activity } from 'lucide-react';
import DashboardOverview from './DashboardOverview';
import EventsManager from './EventsManager';
import NewlyScrapedEvents from './NewlyScrapedEvents';
import ScrapeLogs from './ScrapeLogs';
import UsersManager from './UsersManager';
import MapScreen from './MapScreen';
import { MapPin } from 'lucide-react';

export default function DashboardLayout({ user }) {
  const location = useLocation();

  const handleLogout = async () => {
    await signOut(auth);
  };

  const navItems = [
    { name: 'Dashboard', path: '/', icon: LayoutDashboard },
    { name: 'Events Manager', path: '/events', icon: Calendar },
    { name: 'Newly Scraped', path: '/newly-scraped', icon: Activity },
    { name: 'Scrape Logs', path: '/logs', icon: Terminal },
    { name: 'Map View', path: '/map', icon: MapPin },
    { name: 'Users Manager', path: '/users', icon: Users },
  ];

  return (
    <div className="flex h-screen bg-slate-50">
      {/* Sidebar */}
      <div className="w-64 bg-white border-r border-slate-200 flex flex-col">
        <div className="h-16 flex items-center px-6 border-b border-slate-200">
          <h1 className="text-xl font-bold text-blue-600">ActiveMY Admin</h1>
        </div>
        
        <nav className="flex-1 py-4 px-3 space-y-1">
          {navItems.map((item) => {
            const isActive = location.pathname === item.path || (item.path !== '/' && location.pathname.startsWith(item.path));
            return (
              <Link
                key={item.name}
                to={item.path}
                className={`flex items-center px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-blue-50 text-blue-700'
                    : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                }`}
              >
                <item.icon className={`mr-3 h-5 w-5 ${isActive ? 'text-blue-600' : 'text-slate-400'}`} />
                {item.name}
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-slate-200">
          <div className="flex items-center mb-4 px-2">
            <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold">
              {user?.email?.[0].toUpperCase()}
            </div>
            <div className="ml-3">
              <p className="text-sm font-medium text-slate-700 truncate">{user?.email}</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center w-full px-3 py-2 text-sm font-medium text-red-600 rounded-lg hover:bg-red-50 transition-colors"
          >
            <LogOut className="mr-3 h-5 w-5" />
            Logout
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 overflow-auto">
        <div className="p-8">
          <Routes>
            <Route path="/" element={<DashboardOverview />} />
            <Route path="/events" element={<EventsManager />} />
            <Route path="/newly-scraped" element={<NewlyScrapedEvents />} />
            <Route path="/map" element={<MapScreen />} />
            <Route path="/logs" element={<ScrapeLogs />} />
            <Route path="/users" element={<UsersManager />} />
          </Routes>
        </div>
      </div>
    </div>
  );
}
