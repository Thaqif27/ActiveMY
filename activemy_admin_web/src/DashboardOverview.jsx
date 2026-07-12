import React, { useEffect, useState } from 'react';
import { collection, getCountFromServer, query, where, getDocs } from 'firebase/firestore';
import { db } from './firebase';
import { Users, Calendar, Activity, Clock } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export default function DashboardOverview() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalEvents: 0,
    newlyScraped: 0,
    activeEvents: 0,
    totalLogs: 0
  });
  const [loading, setLoading] = useState(true);
  const [categoryData, setCategoryData] = useState([]);

  useEffect(() => {
    async function fetchStats() {
      try {
        const usersSnap = await getCountFromServer(collection(db, 'users'));
        const eventsSnap = await getCountFromServer(collection(db, 'events'));
        const newlyScrapedSnap = await getCountFromServer(query(collection(db, 'events'), where('status', '==', 'pending')));
        
        // Fetch categories for chart and active events
        const eventsDocs = await getDocs(collection(db, 'events'));
        const counts = {};
        let activeCount = 0;
        
        const today = new Date();
        today.setHours(0,0,0,0);

        eventsDocs.forEach(doc => {
          const data = doc.data();
          let rawCat = data.category || 'Uncategorized';
          const cat = rawCat.charAt(0).toUpperCase() + rawCat.slice(1).toLowerCase();
          counts[cat] = (counts[cat] || 0) + 1;
          
          const eventDateObj = typeof data.date === 'object' && data.date?.toDate ? data.date.toDate() : new Date(data.date || 0);
          if (eventDateObj >= today) {
            activeCount++;
          }
        });
        const chartData = Object.keys(counts).map(key => ({ name: key, events: counts[key] }));
        setCategoryData(chartData);

        let logsCount = 0;
        try {
           const logsSnap = await getCountFromServer(collection(db, 'scraper_logs'));
           logsCount = logsSnap.data().count;
        } catch(e) {}

        setStats({
          totalUsers: usersSnap.data().count,
          totalEvents: eventsSnap.data().count,
          newlyScraped: newlyScrapedSnap.data().count,
          activeEvents: activeCount,
          totalLogs: logsCount
        });
      } catch (error) {
        console.error("Error fetching stats: ", error);
      } finally {
        setLoading(false);
      }
    }

    fetchStats();
  }, []);

  const statCards = [
    { title: 'Total Users', value: stats.totalUsers, icon: Users, color: 'bg-blue-500' },
    { title: 'Active Events', value: stats.activeEvents, icon: Activity, color: 'bg-orange-500' },
    { title: 'Total Events', value: stats.totalEvents, icon: Calendar, color: 'bg-green-500' },
    { title: 'Newly Scraped', value: stats.newlyScraped, icon: Activity, color: 'bg-amber-500' },
    { title: 'Scrape Logs', value: stats.totalLogs, icon: Clock, color: 'bg-purple-500' },
  ];

  if (loading) {
    return <div className="text-slate-500">Loading Dashboard...</div>;
  }

  return (
    <div>
      <h2 className="text-2xl font-bold text-slate-800 mb-6">Dashboard Overview</h2>
      
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-6">
        {statCards.map((stat, idx) => (
          <div key={idx} className="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center">
            <div className={`p-4 rounded-lg text-white ${stat.color} mr-4`}>
              <stat.icon size={24} />
            </div>
            <div>
              <p className="text-sm font-medium text-slate-500">{stat.title}</p>
              <p className="text-3xl font-bold text-slate-800">{stat.value}</p>
            </div>
          </div>
        ))}
      </div>
      
      <div className="mt-8 bg-white rounded-xl shadow-sm border border-slate-200 p-6">
        <h3 className="text-lg font-bold text-slate-800 mb-6">Events by Category</h3>
        <div className="h-80 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={categoryData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" vertical={false} />
              <XAxis dataKey="name" axisLine={false} tickLine={false} />
              <YAxis axisLine={false} tickLine={false} />
              <Tooltip cursor={{fill: '#f1f5f9'}} contentStyle={{borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)'}} />
              <Bar dataKey="events" fill="#3b82f6" radius={[4, 4, 0, 0]} barSize={40} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}
