import React, { useEffect, useState } from 'react';
import { collection, query, getDocs, orderBy, limit, doc, onSnapshot, setDoc } from 'firebase/firestore';
import { db } from './firebase';
import { Terminal, Settings, Activity, Clock, PlayCircle, AlertCircle } from 'lucide-react';

const SCRAPERS = [
  { id: 'jomrun', name: 'JomRun' },
  { id: 'ticket2u', name: 'Ticket2U' },
  { id: 'racexasia', name: 'RaceXasia' },
  { id: 'malaysiarunner', name: 'Malaysia Runner' },
  { id: 'malaysiacyclist', name: 'Malaysia Cyclist' },
  { id: 'sohikers', name: 'So Hikers' }
];

export default function ScrapeLogs() {
  const [logs, setLogs] = useState([]);
  const [settings, setSettings] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchLogs();
    
    // Subscribe to all scraper settings
    const unsubs = SCRAPERS.map(scraper => {
      return onSnapshot(doc(db, 'settings', `scraper_${scraper.id}`), (docSnap) => {
        if (docSnap.exists()) {
          setSettings(prev => ({ ...prev, [scraper.id]: docSnap.data() }));
        } else {
          // Initialize if missing
          setDoc(doc(db, 'settings', `scraper_${scraper.id}`), {
            enabled: false,
            run_hour: 2,
            status: 'idle',
            last_run: null
          });
        }
      });
    });
    
    return () => unsubs.forEach(unsub => unsub());
  }, []);

  async function fetchLogs() {
    setLoading(true);
    try {
      const q = query(collection(db, 'scraper_logs'), orderBy('timestamp', 'desc'), limit(50));
      const snapshot = await getDocs(q);
      const fetchedLogs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setLogs(fetchedLogs);
    } catch (error) {
      console.error("Error fetching logs: ", error);
    } finally {
      setLoading(false);
    }
  }

  const updateSetting = async (source, field, value) => {
    try {
      await setDoc(doc(db, 'settings', `scraper_${source}`), { [field]: value }, { merge: true });
    } catch (e) {
      console.error(`Failed to update setting for ${source}`, e);
      alert(`Gagal menyimpan tetapan. Ralat: ${e.message}`);
    }
  };

  const triggerNow = async (source) => {
    try {
      // Set status to running in UI
      await setDoc(doc(db, 'settings', `scraper_${source}`), { status: 'running' }, { merge: true });
      
      // Hit the API
      // Use local API for testing if we are in dev, otherwise production URL
      // Adjust the URL if you have a specific production URL
      const apiUrl = window.location.hostname === 'localhost' 
        ? `http://localhost:8000/scrape/${source}`
        : `https://goldfish-app-n6w8a.ondigitalocean.app/scrape/${source}`;
        
      fetch(apiUrl, { method: 'POST' }).catch(e => console.error("API error", e));
      
      alert(`${source.toUpperCase()} scraper triggered! Check logs soon.`);
    } catch (e) {
      console.error(e);
      alert(`Failed to trigger ${source}`);
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-slate-800">Scraper Management</h2>
        <button onClick={fetchLogs} className="text-sm bg-white border border-slate-300 px-4 py-2 rounded-md hover:bg-slate-50 font-medium text-slate-700 shadow-sm">
          Refresh Logs
        </button>
      </div>

      {/* Scraper Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        {SCRAPERS.map(scraper => {
          const config = settings[scraper.id] || { enabled: false, run_hour: 2, status: 'idle', last_run: null };
          const isRunning = config.status === 'running';
          
          return (
            <div key={scraper.id} className="bg-white rounded-xl shadow-sm border border-slate-200 p-5 flex flex-col relative overflow-hidden">
              {isRunning && (
                <div className="absolute top-0 left-0 right-0 h-1 bg-blue-500 animate-pulse"></div>
              )}
              
              <div className="flex justify-between items-start mb-4">
                <div className="flex items-center">
                  <Activity className={`h-5 w-5 mr-2 ${isRunning ? 'text-blue-500 animate-spin' : 'text-slate-400'}`} />
                  <h3 className="font-bold text-slate-800 text-lg">{scraper.name}</h3>
                </div>
                <span className={`text-xs font-bold px-2.5 py-1 rounded-full uppercase ${isRunning ? 'bg-blue-100 text-blue-700' : config.status === 'error' ? 'bg-red-100 text-red-700' : 'bg-slate-100 text-slate-600'}`}>
                  {config.status || 'idle'}
                </span>
              </div>

              <div className="space-y-4 mb-6 flex-1">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-slate-600 font-medium">Auto-Scrape Scheduler</span>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input type="checkbox" className="sr-only peer" checked={config.enabled} onChange={(e) => updateSetting(scraper.id, 'enabled', e.target.checked)} />
                    <div className="w-9 h-5 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-green-500"></div>
                  </label>
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-sm text-slate-600 font-medium">Daily Run Time</span>
                  <select 
                    value={config.run_hour || 0} 
                    onChange={(e) => updateSetting(scraper.id, 'run_hour', parseInt(e.target.value))}
                    disabled={!config.enabled}
                    className="bg-slate-50 border border-slate-300 text-slate-800 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block p-1.5 disabled:opacity-50"
                  >
                    {[...Array(24).keys()].map(i => (
                      <option key={i} value={i}>{i.toString().padStart(2, '0')}:00</option>
                    ))}
                  </select>
                </div>
                
                <div className="text-xs text-slate-500 flex items-center">
                  <Clock className="h-3 w-3 mr-1" />
                  Last Run: {config.last_run?.toDate ? config.last_run.toDate().toLocaleString('en-GB') : 'Never'}
                </div>
              </div>

              <button 
                onClick={() => triggerNow(scraper.id)}
                disabled={isRunning}
                className="w-full flex items-center justify-center py-2 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {isRunning ? (
                  <>
                    <Activity className="h-4 w-4 mr-2 animate-spin" />
                    Processing...
                  </>
                ) : (
                  <>
                    <PlayCircle className="h-4 w-4 mr-2" />
                    Scrape Now
                  </>
                )}
              </button>
            </div>
          );
        })}
      </div>

      {/* Logs Console */}
      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="px-6 py-4 border-b border-slate-200 bg-slate-50">
          <h2 className="text-lg font-bold text-slate-800">Recent Scrape Logs</h2>
        </div>
        
        <div className="overflow-y-auto max-h-[600px] p-6">
          {loading ? (
            <div className="text-slate-500 animate-pulse text-center py-8">Fetching logs from server...</div>
          ) : logs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-slate-400">
              <Terminal className="h-12 w-12 mb-4 opacity-50" />
              <p>No scraper logs found.</p>
            </div>
          ) : (
            <div className="space-y-4">
              {logs.map((log) => {
                const dateObj = log.timestamp?.toDate ? log.timestamp.toDate() : new Date(log.timestamp);
                const isSuccess = log.status === 'success';
                const target = log.target || 'ALL';
                
                return (
                  <div key={log.id} className="bg-slate-50 rounded-lg border border-slate-200 p-4">
                    <div className="flex flex-wrap justify-between items-start mb-3">
                      <div className="flex items-center space-x-3 mb-2 sm:mb-0">
                        <div className={`px-2.5 py-1 rounded font-bold text-xs ${isSuccess ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                          {target.toUpperCase()}
                        </div>
                        <div className="text-slate-600 text-sm font-medium flex items-center">
                          <Clock className="h-3 w-3 mr-1" />
                          {dateObj.toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                        </div>
                        <div className="text-slate-500 text-xs font-semibold px-2 py-0.5 rounded bg-slate-200">
                          {log.triggered_by?.toUpperCase() || 'AUTO'}
                        </div>
                      </div>
                      <div className="text-slate-400 text-xs">
                        {log.duration_seconds ? `${log.duration_seconds.toFixed(1)}s` : ''}
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-4 text-sm bg-white p-3 rounded border border-slate-100">
                      <div className="flex items-center">
                        <span className="text-slate-500 mr-2">Status:</span>
                        <span className={`font-semibold ${isSuccess ? 'text-green-600' : 'text-red-600'}`}>
                          {isSuccess ? 'SUCCESS' : 'ERROR'}
                        </span>
                      </div>
                      <div className="w-px h-4 bg-slate-200 hidden sm:block"></div>
                      <div className="flex items-center">
                        <span className="text-slate-500 mr-2">Found:</span>
                        <span className="font-semibold text-slate-800">{log.events_found || 0}</span>
                      </div>
                      <div className="w-px h-4 bg-slate-200 hidden sm:block"></div>
                      <div className="flex items-center">
                        <span className="text-slate-500 mr-2">New Uploaded:</span>
                        <span className="font-bold text-orange-500">{log.events_uploaded || 0}</span>
                      </div>
                      
                      {log.error && (
                        <div className="w-full mt-2 text-xs text-red-500 bg-red-50 p-2 rounded flex items-start">
                          <AlertCircle className="h-4 w-4 mr-1 shrink-0" />
                          <span>{log.error}</span>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
